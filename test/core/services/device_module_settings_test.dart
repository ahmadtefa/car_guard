import 'package:car_guard/core/services/device_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceModuleSettings', () {
    test('parses the /getallsettings payload', () {
      final settings = DeviceModuleSettings.fromJson(<String, dynamic>{
        'maxTemp': 95,
        'fanOnTemp': 85,
        'minVolt': 12,
        'maxVolt': 15,
        'offset': -1.5,
        'r1': 2200,
        'r2': 470,
        'voltCalib': 0.98,
        'sensorPullUp': 4700,
        'installDate': '2025-01-15',
        'serial': 'CG-2025-001',
      });

      expect(settings.maxTemp, 95);
      expect(settings.fanOnTemp, 85);
      expect(settings.minVolt, 12);
      expect(settings.maxVolt, 15);
      expect(settings.offset, -1.5);
      expect(settings.r1, 2200);
      expect(settings.r2, 470);
      expect(settings.voltCalib, 0.98);
      expect(settings.sensorPullUp, 4700);
      expect(settings.installDate, '2025-01-15');
      expect(settings.serial, 'CG-2025-001');
    });

    test('falls back to defaults for missing fields', () {
      const settings = DeviceModuleSettings();

      expect(settings.maxTemp, 95.0);
      expect(settings.fanOnTemp, 85.0);
      expect(settings.minVolt, 12.0);
      expect(settings.maxVolt, 15.0);
      expect(settings.serial, '');
    });

    test('copyWith updates calibration fields and keeps the serial', () {
      const original = DeviceModuleSettings(
        r1: 2200,
        serial: 'CG-1',
        voltCalib: 0.99,
      );

      final updated = original.copyWith(
        maxTemp: 105,
        minVolt: 11.8,
        r2: 470,
        voltCalib: 1.02,
        installDate: '2025-06-01',
      );

      expect(updated.maxTemp, 105);
      expect(updated.minVolt, 11.8);
      expect(updated.r1, 2200, reason: 'untouched fields keep their value');
      expect(updated.r2, 470);
      expect(updated.voltCalib, 1.02);
      expect(updated.installDate, '2025-06-01');
      expect(updated.serial, 'CG-1');
      expect(updated.fanOnTemp, original.fanOnTemp);
    });
  });

  group('ModuleLimits.fillFrom', () {
    test('live stream values always win over stored module settings', () {
      const live = ModuleLimits(maxTemp: 100);
      const stored = DeviceModuleSettings(maxTemp: 95, minVolt: 12.3);

      final merged = live.fillFrom(stored);

      expect(merged.maxTemp, 100);
      expect(merged.minVolt, 12.3);
      expect(merged.maxVolt, 15.0);
    });

    test('missing live values fall back to the stored module settings', () {
      const live = ModuleLimits();
      const stored = DeviceModuleSettings(maxTemp: 97, minVolt: 12.1);

      final merged = live.fillFrom(stored);

      expect(merged.isEmpty, isFalse);
      expect(merged.maxTemp, 97);
      expect(merged.minVolt, 12.1);
    });

    test('a null stored snapshot leaves the live limits untouched', () {
      const live = ModuleLimits(maxTemp: 100);

      final merged = live.fillFrom(null);

      expect(merged.maxTemp, 100);
      expect(merged.minVolt, isNull);
    });
  });
}
