import 'dart:async';

import 'package:car_guard/core/models/device_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/device/repositories/device_repository.dart';
import '../models/dashboard_state.dart';

/// Riverpod provider exposing the dashboard state and subscribing to the
/// repository's live device data updates.
final dashboardProvider = StreamNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
);

/// State notifier that translates repository updates into the dashboard view
/// model while keeping the widget layer free from device-specific logic.
class DashboardNotifier extends StreamNotifier<DashboardState> {
  @override
  Stream<DashboardState> build() async* {
    final repository = ref.read(deviceRepositoryProvider);

    yield const DashboardState(connectionStatus: 'Connecting...');

    try {
      await repository.connect();
      await for (final deviceData in repository.receiveLiveUpdates()) {
        yield _stateFromDeviceData(deviceData);
      }
    } on Object catch (_) {
      yield const DashboardState(connectionStatus: 'Disconnected');
    }
  }

  DashboardState _stateFromDeviceData(DeviceData deviceData) {
    return DashboardState(
      connectionStatus: 'Connected',
      engineTemperature: '${deviceData.temperature.toStringAsFixed(1)} °C',
      batteryVoltage: '${deviceData.voltage.toStringAsFixed(1)} V',
      voltageDifference: '${deviceData.voltageDifference.toStringAsFixed(1)} V',
      coolantLevel: deviceData.coolantLevel.toStringAsFixed(1),
    );
  }
}
