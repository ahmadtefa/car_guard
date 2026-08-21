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
      expect(settings.demoModeEnabled, isFalse);
      expect(settings.themeModeName, 'system');
      expect(settings.maxBatteryVoltage, 15.0);
      expect(settings.dashboardStyleName, 'cards');
      expect(settings.languageName, 'en');
      expect(settings.alarmSoundEnabled, isTrue);
      expect(settings.backgroundMonitoringEnabled, isFalse);
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
        demoModeEnabled: true,
        themeModeName: 'dark',
        maxBatteryVoltage: 14.4,
        dashboardStyleName: 'racing',
        languageName: 'ar',
        alarmSoundEnabled: false,
        backgroundMonitoringEnabled: true,
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
      // Legacy slider thresholds are never persisted anymore: they always
      // come back as defaults even when a custom value was encoded
      // (alerting/gauges follow the module-reported limits).
      expect(restored.engineTempWarning, 100);
      expect(restored.engineTempCritical, 110);
      expect(restored.minBatteryVoltage, 12.2);
      expect(restored.alertCooldown, settings.alertCooldown);
      expect(restored.demoModeEnabled, settings.demoModeEnabled);
      expect(restored.themeModeName, settings.themeModeName);
      expect(restored.maxBatteryVoltage, 15.0);
      expect(restored.dashboardStyleName, settings.dashboardStyleName);
      expect(restored.languageName, settings.languageName);
      expect(restored.alarmSoundEnabled, settings.alarmSoundEnabled);
      expect(
        restored.backgroundMonitoringEnabled,
        settings.backgroundMonitoringEnabled,
      );
      expect(restored.speedLimit, settings.speedLimit);
    });

    test('missing JSON fields fall back to defaults', () {
      final restored = AppSettings.fromJson(<String, dynamic>{});

      expect(restored.deviceHost, '192.168.4.1');
      expect(restored.devicePort, 81);
      expect(restored.engineTempCritical, 110);
    });

    test('invalid dashboard styles fall back to cards', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'dashboardStyleName': 'hologram',
      });

      expect(restored.dashboardStyleName, 'cards');
    });

    test('invalid language names fall back to English', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'languageName': 'fr',
      });

      expect(restored.languageName, 'en');
    });

    test('invalid theme names fall back to system', () {
      final restored = AppSettings.fromJson(<String, dynamic>{
        'themeModeName': 'neon',
      });

      expect(restored.themeModeName, 'system');
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
