import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_status_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/dashboard_state.dart';
import 'voltage_delta_provider.dart';

final dashboardProvider =
    NotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

class DashboardNotifier extends Notifier<DashboardState> {
  bool _dataAccessAllowed = false;
  int _accessGeneration = 0;

  @override
  DashboardState build() {
    final generation = ++_accessGeneration;
    final settingsReady = ref.watch(
      settingsProvider.select((value) => value.value != null),
    );
    // Keep the dashboard shell available while the module is LOCKED; the
    // device-status stream supplies disconnected placeholders until ACTIVE.
    final dataAccessAllowed = settingsReady;
    _dataAccessAllowed = dataAccessAllowed;

    if (!dataAccessAllowed) {
      return const DashboardState();
    }

    // The effective delta can change after the status frame arrives because
    // the history provider may need to append a sample before the 90-second
    // fallback becomes available. Listen separately so DashboardState cannot
    // remain stuck at the module model's old zero default.
    ref.listen<double?>(voltageDeltaProvider, (previous, delta) {
      if (!_dataAccessAllowed || generation != _accessGeneration) return;

      final device = ref.read(deviceStatusProvider).value;
      if (device == null || !device.connected) return;

      state = state.copyWith(
        voltageDifference: _formatVoltageDifference(delta),
      );
    });

    ref.listen(deviceStatusProvider, (previous, next) {
      if (generation != _accessGeneration) return;
      next.when(
        data: (deviceStatus) {
          if (!_dataAccessAllowed || generation != _accessGeneration) return;
          // Keep placeholder values while disconnected instead of flashing
          // misleading zeroes from the disconnected status payload.
          if (!deviceStatus.connected) {
            state = const DashboardState();
            return;
          }

          state = DashboardState(
            connectionStatus:
                deviceStatus.connected ? 'Connected' : 'Disconnected',
            engineTemperature:
                '${deviceStatus.temperatureData.engineTemperature.toStringAsFixed(1)} °C',
            batteryVoltage:
                '${deviceStatus.batteryData.voltage.toStringAsFixed(2)} V',
            voltageDifference: _formatVoltageDifference(
              ref.read(voltageDeltaProvider),
            ),
            coolantLevel: deviceStatus.coolantLevelData.coolantAvailable
                ? 'Available'
                : 'Low',
            fanStatus: deviceStatus.controlData.fanRunning ? 'ON' : 'OFF',
            lastUpdated: _formatClock(deviceStatus.lastUpdated),
          );
        },
        loading: () {},
        error: (error, stackTrace) {
          state = const DashboardState(
            connectionStatus: 'Disconnected',
          );
        },
      );
    }, fireImmediately: true);

    return const DashboardState();
  }

  String _formatVoltageDifference(double? delta) {
    if (delta == null || !delta.isFinite) return '--.- V';
    return '${delta.abs().toStringAsFixed(2)} V';
  }

  String _formatClock(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
