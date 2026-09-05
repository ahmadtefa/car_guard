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
  StreamSubscription<dynamic>? _subscription;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  @override
  Future<void> connect({required String url}) async {
    await disconnect();

    final wsUrl = _normalizeWebSocketUrl(url);

    _channel = WebSocketChannel.connect(
      Uri.parse(wsUrl),
    );

    _subscription = _channel!.stream.listen(
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
    final normalized = url.startsWith('ws://') || url.startsWith('wss://')
        ? url
        : url.startsWith('http://')
            ? url.replaceFirst('http://', 'ws://')
            : url.startsWith('https://')
                ? url.replaceFirst('https://', 'wss://')
                : 'ws://$url';

    final uri = Uri.parse(normalized);
    // Car Guard telemetry uses the module's dedicated WebSocket port. An
    // omitted port must not silently fall back to HTTP port 80.
    return uri.port == 0 ? uri.replace(port: 81).toString() : normalized;
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    try {
      await _channel?.sink.close().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } catch (_) {
      // The peer may already have gone away.
    }
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