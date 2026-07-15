import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Abstract contract for WebSocket infrastructure operations.
abstract class WebSocketService {
  Future<void> connect({required String url});

  Future<void> disconnect();

  Stream<String> get messages;

  Future<void> send(String message);
}

class WebSocketServiceImpl implements WebSocketService {
  WebSocketChannel? _channel;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Future<void> connect({required String url}) async {
    await disconnect();

    final wsUrl = _normalizeWebSocketUrl(url);

    _channel = WebSocketChannel.connect(
      Uri.parse(wsUrl),
    );

    _channel!.stream.listen(
      (message) {
        if (!_controller.isClosed) {
          _controller.add(message.toString());
        }
      },
      onError: (error) {
        if (!_controller.isClosed) {
          _controller.addError(error);
        }
      },
    );
  }

  String _normalizeWebSocketUrl(String url) {
    if (url.startsWith('ws://') || url.startsWith('wss://')) {
      return url;
    }

    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'ws://');
    }

    if (url.startsWith('https://')) {
      return url.replaceFirst('https://', 'wss://');
    }

    return 'ws://$url';
  }

  @override
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Stream<String> get messages => _controller.stream;

  @override
  Future<void> send(String message) async {
    _channel?.sink.add(message);
  }
}

/// Riverpod provider for exposing a WebSocket service implementation.
final webSocketServiceProvider = Provider<WebSocketService>(
  (ref) => WebSocketServiceImpl(),
);