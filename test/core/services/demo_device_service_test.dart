import 'package:car_guard/core/services/demo_device_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoDeviceEngine', () {
    test('keeps the temperature within physical bounds', () {
      var state = const DemoDeviceState(engineTemperature: 120);

      for (var i = 0; i < 500; i++) {
        state = DemoDeviceEngine.tick(state);
        expect(state.engineTemperature, lessThan(126));
        expect(state.engineTemperature, greaterThan(39));
      }
    });

    test('fan eventually turns on and off (thermostat cycles)', () {
      var state = const DemoDeviceState();

      var sawFanOn = false;
      var sawFanOff = false;

      for (var i = 0; i < 600; i++) {
        state = DemoDeviceEngine.tick(state);

        if (state.fanRunning) {
          sawFanOn = true;
        } else {
          sawFanOff = true;
        }
      }

      expect(sawFanOn, isTrue, reason: 'fan should engage when engine heats');
      expect(sawFanOff, isTrue, reason: 'fan should stop after cooling');
    });

    test('occasionally crosses the critical temperature threshold', () {
      var state = const DemoDeviceState();

      var crossedCritical = false;

      for (var i = 0; i < 1000; i++) {
        state = DemoDeviceEngine.tick(state);

        if (state.engineTemperature >= 110) {
          crossedCritical = true;
          break;
        }
      }

      expect(crossedCritical, isTrue);
    });

    test('battery voltage stays in a believable range', () {
      var state = const DemoDeviceState();

      for (var i = 0; i < 400; i++) {
        state = DemoDeviceEngine.tick(state);

        expect(state.batteryVoltage, lessThan(14.5));
        expect(state.batteryVoltage, greaterThan(11.0));
      }
    });

    test('coolant occasionally runs low', () {
      var state = const DemoDeviceState();

      var sawLowCoolant = false;

      for (var i = 0; i < 400; i++) {
        state = DemoDeviceEngine.tick(state);

        if (!state.coolantAvailable) {
          sawLowCoolant = true;
          break;
        }
      }

      expect(sawLowCoolant, isTrue);
    });

    test('buzzer mirrors overheating', () {
      var state = const DemoDeviceState(engineTemperature: 111);

      state = DemoDeviceEngine.tick(state);

      expect(state.buzzerActive, isTrue);
    });

    test('toDeviceStatus reports a connected demo device', () {
      const state = DemoDeviceState(
        engineTemperature: 90,
        fanRunning: true,
        batteryVoltage: 12.4,
      );

      final status = state.toDeviceStatus();

      expect(status.connected, isTrue);
      expect(status.deviceId, contains('Demo'));
      expect(status.temperatureData.engineTemperature, 90);
      expect(status.controlData.fanRunning, isTrue);
    });
  });
}
