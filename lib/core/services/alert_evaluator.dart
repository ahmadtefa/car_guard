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
  ///
  /// [speedKmh] is the live GPS ground speed from the phone (the module has
  /// no GPS). When provided and [AppSettings.speedLimit] is exceeded, a
  /// speeding warning fires. It is evaluated independently of the module
  /// connection — the GPS keeps working even when the module drops.
  static List<DeviceAlert> evaluate(
    DeviceStatus status,
    AppSettings settings, {
    ModuleLimits? moduleLimits,
    double? speedKmh,
    bool hadConnectionBefore = false,
  }) {
    final alerts = <DeviceAlert>[];
    final now = DateTime.now();
    final l = AppL10n(settings.languageName);

    // Speeding is phone-side (GPS), so it never waits for the module.
    final speed = speedKmh;
    if (speed != null && speed >= settings.speedLimit) {
      alerts.add(
        DeviceAlert(
          id: 'speeding',
          title: l.speedingTitle,
          message: l.speedingMessage(
            speed.toStringAsFixed(0),
            settings.speedLimit.toStringAsFixed(0),
          ),
          severity: AlertSeverity.warning,
          timestamp: now,
        ),
      );
    }

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

    // تم التعديل حسب طلب المستخدم: التحذير والإنذار عند نفس الدرجة
    // اللي ظابطها في الجهاز (maxTemp)، بدون فرق 5 درجات.
    // قبل كده كان التحذير عند maxTemp-5 والإنذار عند maxTemp،
    // دلوقتي الاتنين عند نفس القيمة اللي في كارت Module Limits.
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
      }
      // تم إزالة التحذير عند maxTemp-5 — المستخدم يريد الإنذار والتحذير
      // عند نفس الدرجة اللي ظابطها، فلا يوجد تحذير منفصل قبلها.
    }

    final voltage = status.batteryData.voltage;
    final minVolt = moduleLimits?.minVolt;

    // Only an exact 0.0 is treated as "no reading" (firmware placeholder or
    // missing field). Any real below-limit value — including near-zero
    // readings like 0.1 V from a disconnected battery lead — must alarm.
    if (minVolt != null && voltage > 0 && voltage <= minVolt) {
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

    if (maxVolt != null && voltage > 0 && voltage > maxVolt) {
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
