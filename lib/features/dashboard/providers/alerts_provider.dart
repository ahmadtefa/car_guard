import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/models/device_alert.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/alarm_service.dart';
import '../../../core/services/alert_evaluator.dart';
import '../../../core/services/device_models.dart';
import '../../../core/services/notification_service.dart';
import '../../settings/providers/settings_provider.dart';
import 'trip_provider.dart';

/// Immutable state exposed by [alertsProvider].
class AlertsState {
  const AlertsState({
    this.active = const <DeviceAlert>[],
    this.history = const <DeviceAlert>[],
  });

  /// Alerts that are currently firing, sorted oldest first.
  final List<DeviceAlert> active;

  /// Most recent alerts, newest first, capped for memory sanity.
  final List<DeviceAlert> history;

  /// Whether any active alert is critical.
  bool get hasCritical =>
      active.any((alert) => alert.severity == AlertSeverity.critical);
}

/// Watches live device readings, evaluates them against the user settings and
/// raises local notifications for new alerts.
final alertsProvider = NotifierProvider<AlertsNotifier, AlertsState>(
  AlertsNotifier.new,
);

class AlertsNotifier extends Notifier<AlertsState> {
  static const int _maxHistory = 50;

  /// Ids of alerts active on the last evaluation. A notification fires only
  /// when an alert ENTERS this set (transition: quiet -> ringing), so a
  /// continuous condition notifies once, and only a fresh change re-fires.
  final Set<String> _activeAlertIds = {};

  bool _everConnected = false;

  @override
  AlertsState build() {
    _activeAlertIds.clear();
    _everConnected = false;

    ref.listen(deviceStatusProvider, (previous, next) {
      next.whenData((status) => _handleStatus(status));
    });

    // GPS speed ticks come on their own stream — re-evaluate immediately on
    // every fix against the latest module status so speeding never waits
    // for (or depends on) module traffic.
    ref.listen(tripProvider, (previous, next) {
      if (previous?.hasFix == next.hasFix &&
          previous?.speedKmh == next.speedKmh) {
        return;
      }

      final status = ref.read(deviceStatusProvider).value;
      if (status != null) {
        unawaited(_handleStatus(status));
      }
    });

    return const AlertsState();
  }

  Future<void> _handleStatus(DeviceStatus status) async {
    if (status.connected) {
      _everConnected = true;
    }

    final local =
        ref.read(settingsProvider).value ?? const AppSettings();

    if (!local.alertsEnabled) {
      state = AlertsState(active: const [], history: state.history);
      await _updateSiren(const [], local);
      return;
    }

    // Sensor alerts follow the limits reported by the module itself — the
    // removed app-side sliders no longer participate anywhere. Speed comes
    // from the phone GPS instead: it is compared against the app-stored
    // AppSettings.speedLimit in the same pass.
    final trip = ref.read(tripProvider);

    final alerts = AlertEvaluator.evaluate(
      status,
      local,
      moduleLimits: status.moduleLimits,
      speedKmh: trip.hasFix ? trip.speedKmh : null,
      hadConnectionBefore: _everConnected,
    );

    final currentIds = alerts.map((a) => a.id).toSet();

    // Edge-triggered notifications: only alerts that were NOT active on the
    // previous reading produce a notification. A 1-hour disconnection rings
    // exactly once; the next ring happens only after it recovered and got
    // lost again.
    final entered = <DeviceAlert>[];
    for (final alert in alerts) {
      if (!_activeAlertIds.contains(alert.id)) entered.add(alert);
    }

    _activeAlertIds
      ..clear()
      ..addAll(currentIds);

    await _notifyNewAlerts(entered, local);
    await _updateSiren(alerts, local);

    // Prepend alerts to the history while avoiding flooding it with the same
    // alert repeating on every reading (the device streams ~1 value/second).
    var history = state.history;
    for (final alert in alerts) {
      if (history.isEmpty || history.first.id != alert.id) {
        history = [alert, ...history];
      }
    }

    if (history.length > _maxHistory) {
      history = history.sublist(0, _maxHistory);
    }

    state = AlertsState(active: alerts, history: history);
  }

  /// Starts/stops the in-app alarm based on active alerts and the user's
  /// alarm-sound preference (kept from the local settings). Engine
  /// temperature alerts use their dedicated urgent sound.
  Future<void> _updateSiren(
    List<DeviceAlert> alerts,
    AppSettings local,
  ) async {
    final alarm = ref.read(alarmServiceProvider);

    final audible =
        alerts.any((alert) => alert.severity != AlertSeverity.info);

    if (audible && local.alarmSoundEnabled) {
      final engineAlert = alerts.any(
        (alert) => alert.id == 'engine_overheat' || alert.id == 'engine_temp_high',
      );

      final asset = engineAlert
          ? AlarmSounds.engineOverheat
          : AlarmSounds.siren;

      // start() is a no-op when the same asset is already looping and
      // switches seamlessly when the cause changed.
      await alarm.start(asset: asset);
    } else if (alarm.isPlaying) {
      await alarm.stop();
    }
  }

  Future<void> _notifyNewAlerts(
    List<DeviceAlert> alerts,
    AppSettings settings,
  ) async {
    if (alerts.isEmpty) return;

    final notifications = ref.read(notificationServiceProvider);

    for (final alert in alerts) {
      try {
        await notifications.show(title: alert.title, body: alert.message);
      } catch (_) {
        // Notification failures must never break the dashboard stream.
      }
    }
  }
}
