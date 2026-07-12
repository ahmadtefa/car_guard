import 'dart:async';

import 'package:car_guard/core/services/websocket_service.dart';

import 'device_http_service.dart';

/// Generic stream-based transport abstraction reserved for future firmware
/// streaming contracts.
abstract class DeviceStreamTransport extends DeviceTransport {
  /// Returns the current transport state.
  DeviceTransportState get state;
}

/// WebSocket-backed transport implementation for the device repository.
///
/// This implementation is intentionally transport-focused and keeps the
/// repository contract free from UI and business concerns. It uses the shared
/// core [WebSocketService] abstraction for dependency injection compatibility.
class WebSocketDeviceTransport implements DeviceStreamTransport {
  /// Creates a WebSocket transport implementation.
  WebSocketDeviceTransport({required this.webSocketService});

  final WebSocketService webSocketService;

  /// The current connection state of the transport.
  DeviceTransportState _state = DeviceTransportState.disconnected;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  DeviceTransportState get state => _state;

  @override
  Future<void> connect({String? endpoint}) async {
    _state = DeviceTransportState.connecting;
    await webSocketService.connect(url: endpoint ?? '');
    _state = DeviceTransportState.connected;
  }

  @override
  Future<void> disconnect() async {
    _state = DeviceTransportState.disconnected;
    await webSocketService.disconnect();
  }

  @override
  Future<bool> isConnected() async => state == DeviceTransportState.connected;

  @override
  Future<Map<String, dynamic>> readJson({required String endpoint}) async {
    await connect(endpoint: endpoint);
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    await connect(endpoint: endpoint);
    await webSocketService.send(_serialize(payload));
    return <String, dynamic>{};
  }

  @override
  Stream<Map<String, dynamic>> receiveLiveUpdates() {
    return _messageController.stream;
  }

  @override
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  /// Sends a message over the underlying WebSocket connection.
  Future<void> send(String message) async {
    if (state != DeviceTransportState.connected) {
      await connect();
    }
    await webSocketService.send(message);
  }

  /// Disposes the transport and closes any active streams.
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }

  String _serialize(Map<String, dynamic> payload) {
    return payload.toString();
  }
}
