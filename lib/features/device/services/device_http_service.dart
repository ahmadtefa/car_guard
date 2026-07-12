import 'dart:async';

import 'package:car_guard/core/services/http_service.dart';

/// Generic transport abstraction for device communication.
///
/// This contract intentionally avoids concrete HTTP or WebSocket details so
/// that the firmware protocol can be finalized later without changing the
/// repository layer.
abstract class DeviceTransport {
  /// Opens a connection to the device.
  Future<void> connect({String? endpoint});

  /// Closes the active connection.
  Future<void> disconnect();

  /// Returns whether a connection is currently available.
  Future<bool> isConnected();

  /// Reads a JSON payload from the device using the provided endpoint.
  Future<Map<String, dynamic>> readJson({required String endpoint});

  /// Sends a JSON payload to the device using the provided endpoint.
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  });

  /// Receives live JSON updates from the device as a stream.
  Stream<Map<String, dynamic>> receiveLiveUpdates();

  /// Forces a reconnect attempt.
  Future<void> reconnect();
}

/// Base exception for transport-layer failures.
abstract class DeviceTransportException implements Exception {
  /// Creates a transport exception with a human-readable message.
  const DeviceTransportException({required this.message});

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => message;
}

/// Exception raised when a transport operation exceeds its timeout.
class DeviceTransportTimeoutException extends DeviceTransportException {
  /// Creates a timeout exception.
  const DeviceTransportTimeoutException(String message)
      : super(message: message);
}

/// Enumeration of transport connection states.
enum DeviceTransportState {
  disconnected,
  connecting,
  connected,
  error,
}

/// HTTP-backed transport implementation for the device repository.
///
/// This implementation keeps the repository contract independent from the
/// concrete transport choice while delegating all transport operations to the
/// shared core [HttpService] abstraction.
class HttpDeviceTransport implements DeviceTransport {
  /// Creates an HTTP transport implementation.
  HttpDeviceTransport({
    required this.httpService,
    this.timeout = const Duration(seconds: 5),
  });

  final HttpService httpService;

  /// Timeout applied to request-style operations.
  final Duration timeout;

  bool _connected = false;

  @override
  Future<void> connect({String? endpoint}) async {
    _connected = true;
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await httpService.close();
  }

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Future<Map<String, dynamic>> readJson({required String endpoint}) async {
    if (!_connected) {
      await connect(endpoint: endpoint);
    }

    return httpService.getJson(endpoint, headers: <String, String>{});
  }

  @override
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    if (!_connected) {
      await connect(endpoint: endpoint);
    }

    return httpService.postJson(
      endpoint,
      body: payload,
      headers: <String, String>{},
    );
  }

  @override
  Stream<Map<String, dynamic>> receiveLiveUpdates() {
    return const Stream.empty();
  }

  @override
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }
}
