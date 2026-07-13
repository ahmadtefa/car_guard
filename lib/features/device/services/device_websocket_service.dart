import 'dart:async';
import 'dart:convert';

import 'package:car_guard/core/services/websocket_service.dart';

import 'device_http_service.dart';

abstract class DeviceStreamTransport extends DeviceTransport {
  DeviceTransportState get state;
}

class WebSocketDeviceTransport implements DeviceStreamTransport {
  WebSocketDeviceTransport({
    required this.webSocketService,
  });

  final WebSocketService webSocketService;

  DeviceTransportState _state = DeviceTransportState.disconnected;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<String>? _subscription;

  @override
  DeviceTransportState get state => _state;

  @override
  Future<void> connect({String? endpoint}) async {
    if (_state == DeviceTransportState.connected) {
      return;
    }

    _state = DeviceTransportState.connecting;

    await webSocketService.connect(url: endpoint ?? '');

    await _subscription?.cancel();

    _subscription = webSocketService.messages.listen(
      (message) {
        try {
          final json = jsonDecode(message);

          if (json is Map<String, dynamic>) {
            _messageController.add(json);
          } else if (json is Map) {
            _messageController.add(Map<String, dynamic>.from(json));
          }
        } catch (_) {}
      },
      onError: _messageController.addError,
    );

    _state = DeviceTransportState.connected;
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    await webSocketService.disconnect();

    _state = DeviceTransportState.disconnected;
  }

  @override
  Future<bool> isConnected() async =>
      _state == DeviceTransportState.connected;

  @override
  Future<Map<String, dynamic>> readJson({
    required String endpoint,
  }) async {
    throw UnsupportedError(
      'readJson is not supported over WebSocket.',
    );
  }

  @override
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    if (_state != DeviceTransportState.connected) {
      await connect(endpoint: endpoint);
    }

    await webSocketService.send(jsonEncode(payload));

    return payload;
  }

  @override
  Stream<Map<String, dynamic>> receiveLiveUpdates() =>
      _messageController.stream;

  @override
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }
}