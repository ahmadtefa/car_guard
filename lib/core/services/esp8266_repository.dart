import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'device_models.dart';
import 'device_repository.dart';

class Esp8266Repository implements DeviceRepository {
  Esp8266Repository({
    required this.host,
    this.port = 81,
  });

  final String host;
  final int port;

  WebSocketChannel? _channel;
  final StreamController<DeviceStatus> _statusController =
      StreamController<DeviceStatus>.broadcast();

  bool _connected = false;


  @override
  Future<void> connect({required String host, int? port}) async {
    final wsPort = port ?? this.port;

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://$host:$wsPort'),
    );

    _channel!.stream.listen(
      (message) {
        try {
          final json = jsonDecode(message);

          if (json is Map<String, dynamic>) {
            final status = DeviceStatus.fromJson(json);

            _statusController.add(status);
          }
        } catch (_) {}
      },
      onDone: () {
        _connected = false;
      },
      onError: (_) {
        _connected = false;
      },
    );

    _connected = true;
  }


  @override
  Future<void> disconnect() async {
    await _channel?.sink.close();

    _channel = null;
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

    return {};
  }


  @override
  Future<void> sendJson(Map<String, dynamic> payload) async {
    if (!_connected || _channel == null) {
      throw StateError('Device is not connected.');
    }

    _channel!.sink.add(
      jsonEncode(payload),
    );
  }


  @override
  Stream<DeviceStatus> get liveUpdates {
    return _statusController.stream;
  }


  @override
  Future<void> reconnect() async {
    await disconnect();

    await Future.delayed(
      const Duration(seconds: 2),
    );

    await connect(
      host: host,
      port: port,
    );
  }
}