import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/websocket_service.dart';

/// Riverpod provider for exposing the WebSocket infrastructure service contract.
///
/// This provider keeps the transport abstraction available to the rest of the
/// application without introducing implementation details.
/// TODO: Update this wiring when a real WebSocket implementation is added.
final websocketProvider = Provider<WebSocketService>(
  (ref) => ref.watch(webSocketServiceProvider),
);
