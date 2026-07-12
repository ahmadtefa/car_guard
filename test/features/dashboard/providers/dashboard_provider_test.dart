import 'dart:async';

import 'package:car_guard/core/models/device_data.dart';
import 'package:car_guard/features/dashboard/models/dashboard_state.dart';
import 'package:car_guard/features/dashboard/providers/dashboard_provider.dart';
import 'package:car_guard/features/device/models/device_data.dart' as feature_models;
import 'package:car_guard/features/device/repositories/device_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeDeviceRepository implements DeviceRepository {
  _FakeDeviceRepository({required this.stream});

  final Stream<DeviceData> stream;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<Map<String, dynamic>> readJson({required String endpoint}) async {
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    return <String, dynamic>{};
  }

  @override
  Stream<DeviceData> receiveLiveUpdates() => stream;

  @override
  Future<void> reconnect() async {}

  @override
  Future<feature_models.DeviceStatus> getDeviceStatus() async =>
      const feature_models.DeviceStatus();

  @override
  Future<feature_models.SensorData> readSensorData() async =>
      const feature_models.SensorData();

  @override
  Future<feature_models.BatteryData> readBatteryData() async =>
      const feature_models.BatteryData();

  @override
  Future<feature_models.TemperatureData> readTemperatureData() async =>
      const feature_models.TemperatureData();

  @override
  Future<feature_models.CoolantLevelData> readCoolantLevelData() async =>
      const feature_models.CoolantLevelData();
}

void main() {
  test('dashboard provider reacts to live device updates', () async {
    final controller = StreamController<DeviceData>.broadcast();
    final repository = _FakeDeviceRepository(stream: controller.stream);

    final container = ProviderContainer(
      overrides: [
        deviceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.delayed(Duration.zero);

    final initialState = container.read(dashboardProvider).when(
      data: (state) => state,
      loading: () => const DashboardState(),
      error: (error, stackTrace) => const DashboardState(),
    );
    expect(initialState.connectionStatus, 'Connecting...');

    controller.add(
      const DeviceData(
        temperature: 21.5,
        voltage: 13.2,
        voltageDifference: 0.4,
        coolantLevel: 72.0,
        fanState: true,
      ),
    );

    await Future<void>.delayed(Duration.zero);

    final updatedState = container.read(dashboardProvider).when(
      data: (state) => state,
      loading: () => const DashboardState(),
      error: (error, stackTrace) => const DashboardState(),
    );
    expect(updatedState.connectionStatus, 'Connected');
    expect(updatedState.engineTemperature, '21.5 °C');
    expect(updatedState.batteryVoltage, '13.2 V');
    expect(updatedState.voltageDifference, '0.4 V');
    expect(updatedState.coolantLevel, '72.0');
  });
}
