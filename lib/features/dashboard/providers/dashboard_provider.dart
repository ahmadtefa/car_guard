import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_status_provider.dart';
import '../models/dashboard_state.dart';

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    ref.listen(deviceStatusProvider, (previous, next) {
      next.when(
        data: (deviceStatus) {
          // Keep placeholder values while disconnected instead of flashing
          // misleading zeroes from the disconnected status payload.
          if (!deviceStatus.connected) {
            state = const DashboardState();
            return;
          }

          state = DashboardState(
            connectionStatus: deviceStatus.connected
                ? 'Connected'
                : 'Disconnected',

            engineTemperature:
                '${deviceStatus.temperatureData.engineTemperature.toStringAsFixed(1)} °C',

            batteryVoltage:
                '${deviceStatus.batteryData.voltage.toStringAsFixed(2)} V',

            voltageDifference:
                '${deviceStatus.batteryData.voltageDifference.toStringAsFixed(2)} V',

            coolantLevel: deviceStatus.coolantLevelData.coolantAvailable
                ? 'Available'
                : 'Low',

            fanStatus: deviceStatus.controlData.fanRunning ? 'ON' : 'OFF',

            lastUpdated: _formatClock(deviceStatus.lastUpdated),
          );
        },

        loading: () {},

        error: (error, stackTrace) {
          state = const DashboardState(connectionStatus: 'Disconnected');
        },
      );
    });

    return const DashboardState();
  }

  String _formatClock(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
