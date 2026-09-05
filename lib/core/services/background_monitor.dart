import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_l10n.dart';
import '../models/app_settings.dart';
import '../models/device_alert.dart';
import '../models/license_models.dart';
import 'alert_evaluator.dart';
import 'device_models.dart';
import 'notification_service.dart';

/// Entry point executed inside the background service isolate.
///
/// Must stay free of UI dependencies: it reads the saved settings, polls the
/// module every few seconds, evaluates alerts and posts local notifications
/// while the app is in the background or the screen is off.
@pragma('vm:entry-point')
void backgroundMonitorCallback() {
  FlutterForegroundTask.setTaskHandler(BackgroundMonitorHandler());
}

class BackgroundMonitorHandler extends TaskHandler {
  /// Ids of alerts currently ringing. A notification only fires when an id
  /// enters the set (quiet -> ringing), so an hour-long disconnection pings
  /// exactly once instead of every poll.
  final Set<String> _activeAlertIds = {};

  final NotificationService _notifications = NotificationServiceImpl();

  bool _everConnected = false;
  bool _lastFetchWasLicenseLocked = false;

  /// True after the offline alarm has rung for the current disconnection
  /// streak; reset to false on the next successful read so a fresh drop
  /// rings again (once).
  bool _offlineNotified = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _notifications.initialize();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Nothing to clean up; the notification is managed by the service.
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final prefs = await SharedPreferences.getInstance();

    final settings = AppSettings.fromRaw(
      prefs.getString(AppSettings.storageKey),
    );

    if (!settings.alertsEnabled ||
        !settings.backgroundMonitoringEnabled ||
        settings.demoModeEnabled) {
      // Demo mode must stay on the built-in simulator; never poll a real
      // module from the background service in that mode.
      return;
    }

    // [STA+mDNS] When the module joined a hotspot, its address is dynamic —
    // the foreground app records the mDNS-discovered one under this key.
    final discoveredIp = prefs.getString('mdns_module_ip')?.trim();
    final hostToQuery =
        (discoveredIp != null && discoveredIp.isNotEmpty)
            ? discoveredIp
            : settings.deviceHost;

    final status = await _fetchStatus(hostToQuery);

    if (status == null) {
      if (_lastFetchWasLicenseLocked) {
        // A locked/expired module is reachable, not disconnected. Clear old
        // alert notifications and keep the foreground-service text free of
        // stale temperature/voltage values.
        _activeAlertIds.clear();
        _offlineNotified = false;
        await _notifications.clear();
        try {
          await FlutterForegroundTask.updateService(
            notificationText: 'License required',
          );
        } catch (_) {}
        return;
      }

      await _maybeNotifyConnectionLost(settings);
      return;
    }

    _everConnected = true;
    // Back online after a fetchable read: re-arm the offline notifier so
    // the next *new* drop rings exactly once.
    _offlineNotified = false;

    // Sensor alerts follow the module's own limits only — the removed
    // app-side sliders no longer participate anywhere (foreground behaves
    // the same way through alerts_provider). Live stream values win; any
    // limit the firmware omits falls back to the cached /getallsettings
    // snapshot, and finally to the firmware defaults, so the module alarms
    // never silently turn off.
    final cachedLimits =
        _cachedModuleSettings(prefs) ?? const DeviceModuleSettings();

    final alerts = AlertEvaluator.evaluate(
      status,
      settings,
      moduleLimits: status.moduleLimits.fillFrom(cachedLimits),
      hadConnectionBefore: true,
    );

    await _notifyAlerts(alerts, settings);

    try {
      await FlutterForegroundTask.updateService(
        notificationText:
            '${status.temperatureData.engineTemperature.toStringAsFixed(1)} °C'
            ' • ${status.batteryData.voltage.toStringAsFixed(2)} V'
            '${status.controlData.fanRunning ? ' • FAN ON' : ''}',
      );
    } catch (_) {
      // Updating the persistent notification is best-effort.
    }
  }

  Future<DeviceStatus?> _fetchStatus(String host) async {
    _lastFetchWasLicenseLocked = false;
    try {
      final response = await http
          .get(Uri.parse('http://$host/data'))
          .timeout(const Duration(seconds: 4));

      // The ESP8266 remains the authority for the background isolate too:
      // accept only a successful response carrying real telemetry. A license
      // protocol object or any HTTP error is never reinterpreted as a reading.
      if (response.statusCode != 200) return null;

      final body = response.body.trim();

      if (body.startsWith('{')) {
        // A license reply is not telemetry. Never reinterpret a protocol
        // status/result object as a zero-filled sensor reading.
        if (parseLicenseMessage(body) != null) return null;

        final decoded = jsonDecode(body);
        if (decoded is! Map) return null;
        final json = Map<String, dynamic>.from(decoded);
        final licenseStatus = json['licenseStatus'];
        if (licenseStatus is String && licenseStatus != 'ACTIVE') {
          _lastFetchWasLicenseLocked = true;
          return null;
        }
        return _statusFromJson(json);
      }

      return _statusFromCsv(body);
    } catch (_) {
      return null;
    }
  }

  DeviceStatus? _statusFromJson(Map<String, dynamic> json) {
    final licenseStatus = json['licenseStatus'];
    if (licenseStatus is String && licenseStatus != 'ACTIVE') {
      _lastFetchWasLicenseLocked = true;
      return null;
    }

    // Do not turn a generic JSON error/license object into zero-valued
    // telemetry. A real JSON reading must carry the two primary sensors.
    final rawTemperature = json['temp'];
    final rawVoltage = json['volt'];
    if (rawTemperature is! num || rawVoltage is! num) return null;

    final rawCoolant = json['coolant'] ?? json['coolantAvailable'];

    return DeviceStatus(
      connected: true,
      deviceId: 'Car Guard',
      batteryData: BatteryData(
        voltage: rawVoltage.toDouble(),
        voltageDifference: (json['voltDiff'] as num?)?.toDouble() ?? 0,
      ),
      temperatureData: TemperatureData(
        engineTemperature: rawTemperature.toDouble(),
      ),
      coolantLevelData: CoolantLevelData(
        coolantAvailable: rawCoolant == null || rawCoolant == 1 || rawCoolant == true,
      ),
      controlData: DeviceControlData(
        fanRunning: json['fanState'] == 1 || json['fanState'] == true,
        buzzerActive:
            json['buzzerState'] == 1 || json['alarm'] == 1,
      ),
      moduleLimits: ModuleLimits.fromJson(json),
      lastUpdated: DateTime.now(),
    );
  }

  DeviceStatus? _statusFromCsv(String raw) {
    // Reference protocol: temp,volt,fanState,?,maxTemp,fanOnTemp,minVolt,
    // maxVolt,offset
    final parts = raw.split(',');

    if (parts.length < 3) return null;

    final temperature = double.tryParse(parts[0].trim());
    final voltage = double.tryParse(parts[1].trim());
    if (temperature == null || voltage == null) return null;

    return DeviceStatus(
      connected: true,
      deviceId: 'Car Guard',
      batteryData: BatteryData(
        voltage: voltage,
      ),
      temperatureData: TemperatureData(
        engineTemperature: temperature,
      ),
      coolantLevelData: const CoolantLevelData(coolantAvailable: true),
      controlData: DeviceControlData(
        fanRunning: parts[2].trim() == '1',
      ),
      moduleLimits: ModuleLimits(
        maxTemp: parts.length > 4 ? double.tryParse(parts[4].trim()) : null,
        fanOnTemp: parts.length > 5 ? double.tryParse(parts[5].trim()) : null,
        minVolt: parts.length > 6 ? double.tryParse(parts[6].trim()) : null,
        maxVolt: parts.length > 7 ? double.tryParse(parts[7].trim()) : null,
        offset: parts.length > 8 ? double.tryParse(parts[8].trim()) : null,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  /// Reads the module settings snapshot the app cached after its last
  /// successful `/getallsettings` (foreground shares it via SharedPreferences
  /// with the same key used by Esp8266Repository.moduleLimitsCacheKey).
  DeviceModuleSettings? _cachedModuleSettings(SharedPreferences prefs) {
    try {
      final raw = prefs.getString('module_limits_cache');
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      return DeviceModuleSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _notifyAlerts(
    List<DeviceAlert> alerts,
    AppSettings settings,
  ) async {
    final entered = <DeviceAlert>[];
    for (final alert in alerts) {
      if (!_activeAlertIds.contains(alert.id)) {
        entered.add(alert);
        _activeAlertIds.add(alert.id);
      }
    }

    // If nothing cleared, keep the gates open — subsequent polls compare
    // against this set.
    if (entered.isEmpty && alerts.isEmpty) {
      _activeAlertIds.clear(); // everything cleared: next ring is a new event
      return;
    }

    try {
      final existing = alerts.map((a) => a.id).toSet();
      _activeAlertIds
        ..retainWhere(existing.contains)
        ..addAll(entered.map((a) => a.id));
    } catch (_) {}

    for (final alert in entered) {
      if (alert.id == 'connection_lost' && !settings.connectionAlertsEnabled) {
        continue;
      }

      try {
        await _notifications.show(title: alert.title, body: alert.message);
      } catch (_) {
        // Notification failures must not kill the service.
      }
    }
  }

  Future<void> _maybeNotifyConnectionLost(AppSettings settings) async {
    if (!settings.connectionAlertsEnabled || !_everConnected) return;

    // Edge-triggered like the foreground notifier: a continuous offline
    // streak rings ONCE, and the next ring only happens after a recovery
    // puts us back online (re-arm) — never one notification per poll.
    if (_offlineNotified) return;
    _offlineNotified = true;

    final l = AppL10n(settings.languageName);

    try {
      await _notifications.show(
        title: l.connectionLostTitle,
        body: l.connectionLostMessage,
      );
    } catch (_) {
      // Notification failures must not kill the service.
    }
  }
}

/// Starts/stops the Android foreground monitoring service.
abstract final class BackgroundMonitor {
  /// False on web, desktop and iOS where the service is not supported.
  static bool get _supported =>
      !kIsWeb && Platform.isAndroid;

  static void _init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'car_guard_background',
        channelName: 'Car Guard Background Monitoring',
        channelDescription:
            'Keeps watching vehicle readings while the screen is off.',
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Last startup failure details, surfaced to the UI for diagnosis.
  static String? lastError;

  /// Starts the monitoring service; returns whether it is now running.
  static Future<bool> start() async {
    lastError = null;

    debugPrint('BG MONITOR: start() — supported=$_supported');

    if (!_supported) {
      lastError = 'Not supported on this platform';
      return false;
    }

    try {
      _init();
      debugPrint('BG MONITOR: init OK');

      if (await FlutterForegroundTask.isRunningService) {
        debugPrint('BG MONITOR: already running');
        return true;
      }

      debugPrint('BG MONITOR: calling startService…');

      final result = await FlutterForegroundTask.startService(
        callback: backgroundMonitorCallback,
        notificationTitle: 'Car Guard',
        notificationText: 'Monitoring vehicle readings…',
      );

      debugPrint('BG MONITOR: result=${result.runtimeType} ($result)');

      // Give the service a moment to bind before verifying.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final running = await FlutterForegroundTask.isRunningService;

      debugPrint('BG MONITOR: startService done, running=$running');

      if (!running) {
        lastError = 'Service did not start (see logs)';
      }

      return running;
    } catch (e) {
      debugPrint('BG MONITOR: START FAILED: $e');
      lastError = e.toString();
      return false;
    }
  }

  /// Stops the monitoring service.
  static Future<void> stop() async {
    if (!_supported) return;

    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Nothing meaningful to do if stopping fails.
    }
  }

  /// Asks Android to exempt the app from battery optimizations so the
  /// service survives aggressive vendor power management.
  static Future<void> requestIgnoreBatteryOptimization() async {
    if (!_supported) return;

    try {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (_) {
      // Best-effort; the user can also do it from system settings.
    }
  }

  /// Called by legacy entry points on app boot.
  ///
  /// Persisted settings alone are not an authorization proof, so this method
  /// may stop an explicitly disabled/demo service but must not start a service.
  /// [CarGuardApp] starts it only after the foreground license provider has
  /// received a fresh ACTIVE response from the ESP8266.
  static Future<void> ensureFromStorage() async {
    if (!_supported) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final settings = AppSettings.fromRaw(
        prefs.getString(AppSettings.storageKey),
      );

      if (!settings.backgroundMonitoringEnabled || settings.demoModeEnabled) {
        await stop();
      }
    } catch (_) {
      // Never block app startup on the background service.
    }
  }
}
