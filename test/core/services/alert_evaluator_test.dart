import 'package:car_guard/core/models/app_settings.dart';
import 'package:car_guard/core/models/device_alert.dart';
import 'package:car_guard/core/services/alert_evaluator.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:flutter_test/flutter_test.dart';

DeviceStatus _status({
  bool connected = true,
  double temperature = 85,
  double voltage = 12.8,
  bool coolantAvailable = true,
}) {
  return DeviceStatus(
    connected: connected,
    deviceId: 'Car Guard',
    batteryData: BatteryData(voltage: voltage),
    temperatureData: TemperatureData(engineTemperature: temperature),
    coolantLevelData: CoolantLevelData(coolantAvailable: coolantAvailable),
    controlData: const DeviceControlData(),
    lastUpdated: DateTime(2026, 1, 1),
  );
}

void main() {
  group('AlertEvaluator', () {
    test('healthy readings produce no alerts', () {
      final alerts = AlertEvaluator.evaluate(
        _status(),
        const AppSettings(),
        moduleLimits: const ModuleLimits(
          maxTemp: 110,
          minVolt: 12.0,
          maxVolt: 15.0,
        ),
        hadConnectionBefore: true,
      );

      expect(alerts, isEmpty);
    });

    test('critical alert once engine temperature reaches the module limit',
        () {
      final alerts = AlertEvaluator.evaluate(
        _status(temperature: 110.5),
        const AppSettings(),
        moduleLimits: const ModuleLimits(maxTemp: 110),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'engine_overheat');
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('warning alert within 5 degrees below the module limit', () {
      final alerts = AlertEvaluator.evaluate(
        _status(temperature: 104),
        const AppSettings(),
        moduleLimits: const ModuleLimits(maxTemp: 105),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'engine_temp_high');
      expect(alerts.single.severity, AlertSeverity.warning);
    });

    test('low battery voltage raises a warning', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 11.9),
        const AppSettings(),
        moduleLimits: const ModuleLimits(minVolt: 12.0),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'battery_low');
      expect(alerts.single.severity, AlertSeverity.warning);
    });

    test('default zero voltage never raises a low battery alert', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 0),
        const AppSettings(),
        moduleLimits: const ModuleLimits(minVolt: 12.0),
      );

      expect(alerts, isEmpty);
    });

    test('high battery voltage raises a critical alert', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 15.6),
        const AppSettings(),
        moduleLimits: const ModuleLimits(maxVolt: 15.0),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'battery_high');
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('voltage inside the module range raises no alert', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 14.2),
        const AppSettings(),
        moduleLimits: const ModuleLimits(minVolt: 12.0, maxVolt: 15.0),
      );

      expect(alerts, isEmpty);
    });

    test('without module limits no sensor alert ever fires', () {
      // Even readings far beyond the old default thresholds stay silent:
      // the removed app-side sliders no longer have any effect.
      final alerts = AlertEvaluator.evaluate(
        _status(temperature: 150, voltage: 16.5),
        const AppSettings(),
      );

      expect(alerts, isEmpty);
    });

    test('stale app-side thresholds stored from the slider era are ignored',
        () {
      final alerts = AlertEvaluator.evaluate(
        _status(temperature: 110, voltage: 11.5),
        const AppSettings(
          engineTempCritical: 90,
          minBatteryVoltage: 13.0,
        ),
        moduleLimits: const ModuleLimits(maxTemp: 120, minVolt: 11.0),
      );

      expect(alerts, isEmpty);
    });

    test('low coolant raises a critical alert when enabled', () {
      final alerts = AlertEvaluator.evaluate(
        _status(coolantAvailable: false),
        const AppSettings(),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'coolant_low');
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('low coolant is ignored when coolant alerts are disabled', () {
      final alerts = AlertEvaluator.evaluate(
        _status(coolantAvailable: false),
        const AppSettings(coolantAlertsEnabled: false),
      );

      expect(alerts, isEmpty);
    });

    test('connection lost only when the device was seen before', () {
      final withHistory = AlertEvaluator.evaluate(
        _status(connected: false),
        const AppSettings(),
        hadConnectionBefore: true,
      );
      final coldStart = AlertEvaluator.evaluate(
        _status(connected: false),
        const AppSettings(),
        hadConnectionBefore: false,
      );

      expect(withHistory, hasLength(1));
      expect(withHistory.single.id, 'connection_lost');
      expect(withHistory.single.severity, AlertSeverity.info);

      expect(coldStart, isEmpty);
    });

    test('sensor alerts are suppressed while disconnected', () {
      final alerts = AlertEvaluator.evaluate(
        _status(connected: false, temperature: 115, voltage: 11),
        const AppSettings(connectionAlertsEnabled: false),
        moduleLimits: const ModuleLimits(maxTemp: 100, minVolt: 12.0),
        hadConnectionBefore: true,
      );

      expect(alerts, isEmpty);
    });
  });
}
