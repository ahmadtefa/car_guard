import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/models/device_alert.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/providers/effective_settings_provider.dart';
import '../../../core/services/alarm_service.dart';
import '../../../core/services/alert_evaluator.dart';
import '../../../core/services/device_models.dart';
import '../../../core/services/notification_service.dart';
import '../../settings/providers/settings_provider.dart';

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

  final Map<String, DateTime> _lastNotifiedAt = {};
  bool _everConnected = false;

  @override
  AlertsState build() {
    _lastNotifiedAt.clear();
    _everConnected = false;

    ref.listen(deviceStatusProvider, (previous, next) {
      next.whenData((status) => _handleStatus(status));
    });

    return const AlertsState();
  }

  Future<void> _handleStatus(DeviceStatus status) async {
    if (status.connected) {
      _everConnected = true;
    }

    final local =
        ref.read(settingsProvider).value ?? const AppSettings();

    // Thresholds may be overridden by limits reported by the module itself.
    final settings = ref.read(effectiveSettingsProvider);

    if (!local.alertsEnabled) {
      state = AlertsState(active: const [], history: state.history);
      await _updateSiren(const [], local);
      return;
    }

    final alerts = AlertEvaluator.evaluate(
      status,
      settings,
      hadConnectionBefore: _everConnected,
    );

    await _notifyNewAlerts(alerts, settings);
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

  /// Starts/stops the in-app siren based on active alerts and the user's
  /// alarm-sound preference (kept from the local settings).
  Future<void> _updateSiren(
    List<DeviceAlert> alerts,
    AppSettings local,
  ) async {
    final alarm = ref.read(alarmServiceProvider);

    final audible =
        alerts.any((alert) => alert.severity != AlertSeverity.info);

    if (audible && local.alarmSoundEnabled && !alarm.isPlaying) {
      await alarm.start();
    } else if ((!audible || !local.alarmSoundEnabled) && alarm.isPlaying) {
      await alarm.stop();
    }
  }

  Future<void> _notifyNewAlerts(
    List<DeviceAlert> alerts,
    AppSettings settings,
  ) async {
    final now = DateTime.now();
    final notifications = ref.read(notificationServiceProvider);

    for (final alert in alerts) {
      final lastNotified = _lastNotifiedAt[alert.id];

      final isDue =
          lastNotified == null ||
          now.difference(lastNotified) >= settings.alertCooldown;

      if (!isDue) continue;

      _lastNotifiedAt[alert.id] = now;

      try {
        await notifications.show(title: alert.title, body: alert.message);
      } catch (_) {
        // Notification failures must never break the dashboard stream.
      }
    }
  }
}
