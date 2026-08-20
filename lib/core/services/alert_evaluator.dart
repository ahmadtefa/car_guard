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

    if (!status.connected) {
      if (settings.connectionAlertsEnabled && hadConnectionBefore) {
        alerts.add(
          DeviceAlert(
            id: 'connection_lost',
            title: 'Connection lost',
            message: 'The Car Guard device is no longer reachable.',
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
          title: 'Engine overheating',
          message:
              'Engine temperature is ${temperature.toStringAsFixed(1)} °C. '
              'Stop safely and check the cooling system.',
          severity: AlertSeverity.critical,
          timestamp: now,
        ),
      );
    } else if (temperature >= settings.engineTempWarning) {
      alerts.add(
        DeviceAlert(
          id: 'engine_temp_high',
          title: 'Engine temperature high',
          message:
              'Engine temperature is ${temperature.toStringAsFixed(1)} °C. '
              'Keep an eye on the gauge.',
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
          title: 'Battery voltage low',
          message:
              'Battery is at ${voltage.toStringAsFixed(2)} V, below the '
              'configured minimum of ${settings.minBatteryVoltage} V.',
          severity: AlertSeverity.warning,
          timestamp: now,
        ),
      );
    }

    if (settings.coolantAlertsEnabled &&
        !status.coolantLevelData.coolantAvailable) {
      alerts.add(
        DeviceAlert(
          id: 'coolant_low',
          title: 'Coolant level low',
          message: 'The coolant reservoir needs a top-up.',
          severity: AlertSeverity.critical,
          timestamp: now,
        ),
      );
    }

    return alerts;
  }
}
