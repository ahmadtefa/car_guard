import '../models/license_models.dart';
import 'device_models.dart';

/// Abstract contract for the device communication repository.
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

  /// Streams the raw connection state (true = transport usable / module alive).
  Stream<bool> get connectionStream;

  /// Streams license-protocol messages answered by the module over the same
  /// transport as [liveUpdates] (no second connection is opened).
  Stream<LicenseMessage> get licenseStream;

  /// Asks the module for its serial (`{"cmd":"DEVICE_SERIAL"}`).
  /// Returns null when no answer/timeout.
  Future<DeviceSerialMessage?> getDeviceSerial();

  /// Asks the module for its current license status. Returns null on timeout.
  Future<LicenseStatusMessage?> getLicenseStatus();

  /// Sends an activation code to the module and awaits the result.
  Future<LicenseResultMessage?> activateLicense(String code);

  /// Attempts to reconnect after a connection failure.
  Future<void> reconnect();
}
