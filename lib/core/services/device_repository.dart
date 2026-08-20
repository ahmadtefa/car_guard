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
