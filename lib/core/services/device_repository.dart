import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_models.dart';

/// Abstract contract for the ESP8266 communication repository.
///
/// This repository is intentionally infrastructure-focused and does not contain
/// UI or feature-specific business logic. It provides a stable interface for
/// later concrete implementations such as HTTP, WebSocket, or serial transport.
abstract class DeviceRepository {
  /// Connects to the target device.
  Future<void> connect({required String host, int? port});

  /// Disconnects from the active device connection.
  Future<void> disconnect();

  /// Returns whether the device is currently connected.
  Future<bool> isConnected();

  /// Reads a JSON payload from the device.
  Future<Map<String, dynamic>> readJson();

  /// Sends a JSON command payload to the device.
  Future<void> sendJson(Map<String, dynamic> payload);

  /// Streams live updates emitted by the device.
  Stream<DeviceStatus> get liveUpdates;

  /// Attempts to reconnect after a connection failure.
  Future<void> reconnect();
}


/// Default placeholder implementation of the repository.
class DeviceRepositoryImpl implements DeviceRepository {
  DeviceRepositoryImpl({
    this.timeoutDuration = const Duration(seconds: 5),
  });

  final Duration timeoutDuration;

  final StreamController<DeviceStatus> _updatesController =
      StreamController<DeviceStatus>.broadcast();

  bool _connected = false;


  @override
  Future<void> connect({required String host, int? port}) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 50),
    );

    _connected = true;
  }


  @override
  Future<void> disconnect() async {
    _connected = false;
  }


  @override
  Future<bool> isConnected() async {
    return _connected;
  }


  @override
  Future<Map<String, dynamic>> readJson() async {
    if (!_connected) {
      throw StateError('Device is not connected.');
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 50),
    );

    return DeviceStatus.disconnected().toJson();
  }


  @override
  Future<void> sendJson(Map<String, dynamic> payload) async {
    if (!_connected) {
      throw StateError('Device is not connected.');
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 50),
    );

    _updatesController.add(
      DeviceStatus(
        connected: true,
        deviceId: 'esp8266',
        batteryData: const BatteryData(
          voltage: 12.6,
        ),
        temperatureData: const TemperatureData(
          engineTemperature: 90.0,
        ),
        coolantLevelData: const CoolantLevelData(
          coolantAvailable: true,
        ),
        controlData: const DeviceControlData(
          fanRunning: false,
          buzzerActive: false,
        ),
        lastUpdated: DateTime.now(),
      ),
    );
  }


  @override
  Stream<DeviceStatus> get liveUpdates {
    return _updatesController.stream;
  }


  @override
  Future<void> reconnect() async {
    await disconnect();

    await Future<void>.delayed(
      timeoutDuration,
    );

    await connect(
      host: '127.0.0.1',
    );
  }
}


/// Riverpod provider for exposing the device repository implementation.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepositoryImpl();
});