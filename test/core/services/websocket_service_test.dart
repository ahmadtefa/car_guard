import 'package:car_guard/core/services/websocket_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeCarGuardWebSocketUrl', () {
    test('uses the module WebSocket port when no port is supplied', () {
      expect(
        normalizeCarGuardWebSocketUrl('192.168.4.1'),
        'ws://192.168.4.1:81',
      );
      expect(
        normalizeCarGuardWebSocketUrl('ws://car_guard.local'),
        'ws://car_guard.local:81',
      );
      expect(
        normalizeCarGuardWebSocketUrl('http://192.168.4.1/data'),
        'ws://192.168.4.1:81/data',
      );
    });

    test('preserves an explicitly configured port', () {
      expect(
        normalizeCarGuardWebSocketUrl('ws://192.168.4.1:8081'),
        'ws://192.168.4.1:8081',
      );
      expect(
        normalizeCarGuardWebSocketUrl('192.168.4.1:9000'),
        'ws://192.168.4.1:9000',
      );
    });

    test('converts HTTPS URLs to secure WebSocket URLs', () {
      expect(
        normalizeCarGuardWebSocketUrl('https://example.test/live'),
        'wss://example.test:81/live',
      );
    });
  });
}
