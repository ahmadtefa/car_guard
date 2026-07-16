import 'package:flutter_test/flutter_test.dart';

import 'package:car_guard/features/dashboard/models/dashboard_state.dart';


void main() {
  group('DashboardState', () {

    test('has default values', () {

      const state = DashboardState();

      expect(
        state.connectionStatus,
        'Disconnected',
      );

      expect(
        state.engineTemperature,
        '-- °C',
      );

      expect(
        state.batteryVoltage,
        '--.- V',
      );

      expect(
        state.voltageDifference,
        '--.- V',
      );

      expect(
        state.coolantLevel,
        '--',
      );

    });

  });
}