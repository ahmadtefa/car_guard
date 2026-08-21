import '../l10n/app_l10n.dart';
import '../models/app_settings.dart';
import '../models/device_alert.dart';
import 'device_models.dart';

/// Pure evaluator that turns a [DeviceStatus] into alerts.
///
/// Sensor alerts (engine temperature / battery voltage) are driven
/// EXCLUSIVELY by the limits the module itself reports in its live stream
/// ([moduleLimits]) — the old app-side threshold sliders were removed
/// together with their effect, so [settings] only contributes the language
/// and the coolant/connection toggles here.
///
/// The evaluator is intentionally side-effect free so it can be unit tested
/// without a live device. Notification delivery and de-duplication live in
/// the alerts notifier that consumes its output.
abstract final class AlertEvaluator {
  /// Evaluates [status] and returns the alerts that should be active.
  ///
  /// [moduleLimits] are the alarm limits the module reported in the same
  /// reading ([DeviceStatus.moduleLimits]); when a limit is missing the
  /// corresponding alert simply never fires — there is no app-side
  /// fallback threshold anymore.
  ///
  /// [hadConnectionBefore] indicates the app has seen a live connection at
  /// least once, which prevents a "connection lost" alert on cold start.
  static List<DeviceAlert> evaluate(
    DeviceStatus status,
    AppSettings settings, {
    ModuleLimits? moduleLimits,
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

    // Alarm temperature stored on the module; the warning level is always
    // 5 °C below it, exactly like the firmware's own buzzer stages.
    final maxTemp = moduleLimits?.maxTemp;

    if (maxTemp != null) {
      if (temperature >= maxTemp) {
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
      } else if (temperature >= maxTemp - 5) {
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
    }

    final voltage = status.batteryData.voltage;
    final minVolt = moduleLimits?.minVolt;

    // The > 1 V guard ignores the default 0.0 reading so a fresh or flaky
    // connection never raises a bogus low-battery alert.
    if (minVolt != null && voltage > 1 && voltage <= minVolt) {
      alerts.add(
        DeviceAlert(
          id: 'battery_low',
          title: l.batteryLowTitle,
          message: l.batteryLowMessage(
            voltage.toStringAsFixed(2),
            minVolt.toStringAsFixed(1),
          ),
          severity: AlertSeverity.warning,
          timestamp: now,
        ),
      );
    }

    final maxVolt = moduleLimits?.maxVolt;

    if (maxVolt != null && voltage > 1 && voltage > maxVolt) {
      alerts.add(
        DeviceAlert(
          id: 'battery_high',
          title: l.batteryHighTitle,
          message: l.batteryHighMessage(
            voltage.toStringAsFixed(2),
            maxVolt.toStringAsFixed(1),
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
