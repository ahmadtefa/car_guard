import '../l10n/app_l10n.dart';
import '../models/app_settings.dart';
import '../models/device_alert.dart';
import 'device_models.dart';

/// Pure evaluator that turns a [DeviceStatus] into alerts based on user
/// settings.
///
/// The evaluator is intentionally side-effect free so it can be unit tested
/// without a live device. Notification delivery and de-duplication live in the
/// alerts notifier that consumes its output.
abstract final class AlertEvaluator {
  /// Evaluates [status] against [settings] and returns the alerts that should
  /// currently be active.
  ///
  /// [hadConnectionBefore] indicates the app has seen a live connection at
  /// least once, which prevents a "connection lost" alert on cold start.
  static List<DeviceAlert> evaluate(
    DeviceStatus status,
    AppSettings settings, {
    bool hadConnectionBefore = false,
  }) {
    final alerts = <DeviceAlert>[];
    final now = DateTime.now();
    final l = AppL10n(settings.languageName);

    if (!status.connected) {
      if (settings.connectionAlertsEnabled && hadConnectionBefore) {
        alerts.add(
          DeviceAlert(
            id: 'connection_lost',
            title: l.connectionLostTitle,
            message: l.connectionLostMessage,
            severity: AlertSeverity.info,
            timestamp: now,
          ),
        );
      }

      return alerts;
    }

    final temperature = status.temperatureData.engineTemperature;

    if (temperature >= settings.engineTempCritical) {
      alerts.add(
        DeviceAlert(
          id: 'engine_overheat',
          title: l.engineOverheatTitle,
          message: l.engineOverheatMessage(
            temperature.toStringAsFixed(1),
          ),
          severity: AlertSeverity.critical,
          timestamp: now,
        ),
      );
    } else if (temperature >= settings.engineTempWarning) {
      alerts.add(
        DeviceAlert(
          id: 'engine_temp_high',
          title: l.engineTempHighTitle,
          message: l.engineTempHighMessage(
            temperature.toStringAsFixed(1),
          ),
          severity: AlertSeverity.warning,
          timestamp: now,
        ),
      );
    }

    final voltage = status.batteryData.voltage;

    // The > 1 V guard ignores the default 0.0 reading so a fresh or flaky
    // connection never raises a bogus low-battery alert.
    if (voltage > 1 && voltage <= settings.minBatteryVoltage) {
      alerts.add(
        DeviceAlert(
          id: 'battery_low',
          title: l.batteryLowTitle,
          message: l.batteryLowMessage(
            voltage.toStringAsFixed(2),
            settings.minBatteryVoltage.toStringAsFixed(1),
          ),
          severity: AlertSeverity.warning,
          timestamp: now,
        ),
      );
    }

    if (voltage > 1 && voltage > settings.maxBatteryVoltage) {
      alerts.add(
        DeviceAlert(
          id: 'battery_high',
          title: l.batteryHighTitle,
          message: l.batteryHighMessage(
            voltage.toStringAsFixed(2),
            settings.maxBatteryVoltage.toStringAsFixed(1),
          ),
          severity: AlertSeverity.critical,
          timestamp: now,
        ),
      );
    }

    if (settings.coolantAlertsEnabled &&
        !status.coolantLevelData.coolantAvailable) {
      alerts.add(
        DeviceAlert(
          id: 'coolant_low',
          title: l.coolantLowTitle,
          message: l.coolantLowMessage,
          severity: AlertSeverity.critical,
          timestamp: now,
        ),
      );
    }

    return alerts;
  }
}
