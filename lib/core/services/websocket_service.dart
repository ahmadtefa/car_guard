import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for WebSocket infrastructure operations.
abstract class WebSocketService {
  /// Establishes a WebSocket connection to the provided endpoint.
  Future<void> connect({required String url});

  /// Closes the active WebSocket connection.
  Future<void> disconnect();

  /// Exposes incoming messages as a stream for later consumers.
  Stream<String> get messages;

  /// Sends a message over the active connection.
  Future<void> send(String message);
}

/// Placeholder implementation for WebSocket infrastructure operations.
/// TODO: Replace this placeholder with a real WebSocket transport implementation.
class WebSocketServiceImpl implements WebSocketService {
  final StreamController<String> _controller = StreamController<String>.broadcast();

  @override
  Future<void> connect({required String url}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<String> get messages => _controller.stream;

  @override
  Future<void> send(String message) async {}
}

/// Riverpod provider for exposing a WebSocket service implementation.
final webSocketServiceProvider = Provider<WebSocketService>(
  (ref) => WebSocketServiceImpl(),
);
