import 'package:car_guard/core/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('has sensible defaults', () {
      const settings = AppSettings();

      expect(settings.deviceHost, '192.168.4.1');
      expect(settings.devicePort, 81);
      expect(settings.alertsEnabled, isTrue);
      expect(settings.engineTempWarning, 100);
      expect(settings.engineTempCritical, 110);
      expect(settings.minBatteryVoltage, 12.2);
      expect(settings.alertCooldown, const Duration(minutes: 5));
    });

    test('round-trips through JSON', () {
      const settings = AppSettings(
        deviceHost: '10.0.0.42',
        devicePort: 8080,
        alertsEnabled: false,
        coolantAlertsEnabled: false,
        connectionAlertsEnabled: true,
        engineTempWarning: 95,
        engineTempCritical: 105,
        minBatteryVoltage: 12.5,
        alertCooldown: Duration(minutes: 10),
      );

      final restored = AppSettings.fromRaw(settings.encode());

      expect(restored.deviceHost, settings.deviceHost);
      expect(restored.devicePort, settings.devicePort);
      expect(restored.alertsEnabled, settings.alertsEnabled);
      expect(restored.coolantAlertsEnabled, settings.coolantAlertsEnabled);
      expect(
        restored.connectionAlertsEnabled,
        settings.connectionAlertsEnabled,
      );
      expect(restored.engineTempWarning, settings.engineTempWarning);
      expect(restored.engineTempCritical, settings.engineTempCritical);
      expect(restored.minBatteryVoltage, settings.minBatteryVoltage);
      expect(restored.alertCooldown, settings.alertCooldown);
    });

    test('missing JSON fields fall back to defaults', () {
      final restored = AppSettings.fromJson(<String, dynamic>{});

      expect(restored.deviceHost, '192.168.4.1');
      expect(restored.devicePort, 81);
      expect(restored.engineTempCritical, 110);
    });

    test('corrupted payloads fall back to defaults', () {
      expect(AppSettings.fromRaw('not json at all'), const AppSettings());
      expect(AppSettings.fromRaw(null), const AppSettings());
      expect(AppSettings.fromRaw(''), const AppSettings());
    });

    test('copyWith only replaces the given fields', () {
      const settings = AppSettings();

      final updated = settings.copyWith(
        deviceHost: '192.168.1.50',
        engineTempWarning: 90,
      );

      expect(updated.deviceHost, '192.168.1.50');
      expect(updated.engineTempWarning, 90);
      expect(updated.devicePort, settings.devicePort);
      expect(updated.minBatteryVoltage, settings.minBatteryVoltage);
    });
  });
}
