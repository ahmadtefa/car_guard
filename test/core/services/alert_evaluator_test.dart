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
        hadConnectionBefore: true,
      );

      expect(alerts, isEmpty);
    });

    test('critical alert once engine temperature reaches critical threshold',
        () {
      final alerts = AlertEvaluator.evaluate(
        _status(temperature: 110.5),
        const AppSettings(),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'engine_overheat');
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('warning alert between warning and critical thresholds', () {
      final alerts = AlertEvaluator.evaluate(
        _status(temperature: 104),
        const AppSettings(),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'engine_temp_high');
      expect(alerts.single.severity, AlertSeverity.warning);
    });

    test('low battery voltage raises a warning', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 11.9),
        const AppSettings(),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'battery_low');
      expect(alerts.single.severity, AlertSeverity.warning);
    });

    test('default zero voltage never raises a low battery alert', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 0),
        const AppSettings(),
      );

      expect(alerts, isEmpty);
    });

    test('high battery voltage raises a critical alert', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 15.6),
        const AppSettings(),
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.id, 'battery_high');
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('voltage inside the configured range raises no alert', () {
      final alerts = AlertEvaluator.evaluate(
        _status(voltage: 14.2),
        const AppSettings(),
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
        hadConnectionBefore: true,
      );

      expect(alerts, isEmpty);
    });
  });
}
