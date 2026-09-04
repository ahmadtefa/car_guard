import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:car_guard/core/services/esp8266_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _activeTelemetry = '90.0,12.6,0,0,95,85,12,15,0,0,0';

/// Small in-process module double. It speaks the same WebSocket protocol as
/// the ESP8266 and also exposes /data so the existing HTTP fallback remains
/// covered without mocking the repository's transport.
class _ModuleServer {
  _ModuleServer({
    this.replyToSerial = false,
    this.replyToStatus = false,
    this.replyToActivation = false,
    this.licenseStatus = 'LOCKED',
    this.licenseType = 'NONE',
    this.sendInitialTelemetry = false,
    this.sendPeriodicTelemetry = false,
    this.httpDataStatus = 403,
    this.httpDataBody = 'DEVICE LOCKED',
  });

  final bool replyToSerial;
  final bool replyToStatus;
  final bool replyToActivation;
  final String licenseStatus;
  final String licenseType;
  final int licenseExpires = 0;
  final bool sendInitialTelemetry;
  final bool sendPeriodicTelemetry;
  final int httpDataStatus;
  final String httpDataBody;

  late HttpServer _server;
  final Set<WebSocket> _sockets = <WebSocket>{};
  final Map<WebSocket, Timer> _telemetryTimers = <WebSocket, Timer>{};
  final List<String> receivedCommands = <String>[];
  var websocketConnectionCount = 0;
  var httpDataRequestCount = 0;
  var _closing = false;

  String get host => InternetAddress.loopbackIPv4.address;
  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      await _upgradeWebSocket(request);
      return;
    }

    final response = request.response;
    if (request.uri.path == '/data') {
      httpDataRequestCount++;
      response.statusCode = httpDataStatus;
      response.headers.contentType = ContentType.text;
      response.write(httpDataBody);
    } else if (request.uri.path == '/getallsettings') {
      // The repository may load module limits after its first active reading.
      response.statusCode = 200;
      response.headers.contentType = ContentType.json;
      response.write('{}');
    } else {
      response.statusCode = 404;
    }
    await response.close();
  }

  Future<void> _upgradeWebSocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    if (_closing) {
      await socket.close();
      return;
    }

    websocketConnectionCount++;
    _sockets.add(socket);
    socket.listen(
      (message) => _handleSocketMessage(socket, message),
      onDone: () => _removeSocket(socket),
    );

    if (sendInitialTelemetry) {
      socket.add(_activeTelemetry);
    }

    if (sendPeriodicTelemetry) {
      _telemetryTimers[socket] = Timer.periodic(
        const Duration(milliseconds: 20),
        (_) {
          if (!_sockets.contains(socket)) return;
          try {
            socket.add(_activeTelemetry);
          } catch (_) {
            // The onDone callback removes the socket and its timer.
          }
        },
      );
    }
  }

  void _handleSocketMessage(WebSocket socket, dynamic message) {
    if (message is! String) return;

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map) return;
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // The repository's initial "hello" frame is intentionally ignored.
      return;
    }

    final command = payload['cmd'];
    if (command is! String) return;
    receivedCommands.add(command);

    switch (command) {
      case 'DEVICE_SERIAL':
        if (replyToSerial) {
          socket.add(
            '{"type":"DEVICE_SERIAL","serial":"KCG_1234ABCD"}',
          );
        }
        break;
      case 'LICENSE_STATUS':
        if (replyToStatus) {
          socket.add(
            '{"type":"LICENSE_STATUS","status":"$licenseStatus",'
            '"licenseType":"$licenseType","expires":$licenseExpires}',
          );
        }
        break;
      case 'LICENSE_ACTIVATE':
        if (replyToActivation) {
          socket.add(
            '{"type":"LICENSE_RESULT","status":"OK",'
            '"reason":"OK","expires":0}',
          );
        }
        break;
    }
  }

  void _removeSocket(WebSocket socket) {
    _sockets.remove(socket);
    _telemetryTimers.remove(socket)?.cancel();
  }

  Future<void> close() async {
    _closing = true;
    for (final timer in _telemetryTimers.values) {
      timer.cancel();
    }
    _telemetryTimers.clear();

    final sockets = List<WebSocket>.of(_sockets);
    for (final socket in sockets) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _sockets.clear();
    await _server.close(force: true);
  }
}

Esp8266Repository _repositoryFor(_ModuleServer server) {
  return Esp8266Repository(
    host: server.host,
    port: server.port,
    httpPort: server.port,
    enableMdnsDiscovery: false,
    // Short timings keep these transport tests focused and fast. Production
    // defaults remain six seconds / three seconds / 1.5 seconds.
    watchdogTimeout: const Duration(milliseconds: 120),
    httpTimeout: const Duration(milliseconds: 80),
    webSocketInitialTimeout: const Duration(milliseconds: 500),
    licenseRequestTimeout: const Duration(milliseconds: 120),
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'condition was not met in time');
}

Future<void> _waitForConnected(
  Esp8266Repository repository, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await repository.isConnected()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(await repository.isConnected(), isTrue,
      reason: 'repository did not become connected in time');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('A. ACTIVE telemetry keeps the existing watchdog healthy', () async {
    final server = _ModuleServer(sendPeriodicTelemetry: true);
    await server.start();
    final repository = _repositoryFor(server);

    try {
      await repository.connect(host: server.host, port: server.port);
      await _waitForConnected(repository);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(await repository.isConnected(), isTrue);
      expect(server.websocketConnectionCount, 1);
    } finally {
      await repository.disconnect();
      await server.close();
    }
  });

  test(
    'B. LOCKED serial proof-of-life prevents a telemetry watchdog reconnect',
    () async {
      final server = _ModuleServer(replyToSerial: true);
      await server.start();
      final repository = _repositoryFor(server);

      try {
        await repository.connect(host: server.host, port: server.port);
        final serial = await repository.getDeviceSerial();

        expect(serial?.serial, 'KCG_1234ABCD');
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(await repository.isConnected(), isTrue);
        expect(server.websocketConnectionCount, 1);
        expect(
          server.receivedCommands,
          contains('DEVICE_SERIAL'),
        );
        expect(server.httpDataRequestCount, 0);
      } finally {
        await repository.disconnect();
        await server.close();
      }
    },
  );

  test(
    'C. LOCKED status proof-of-life prevents a telemetry watchdog reconnect',
    () async {
      final server = _ModuleServer(replyToStatus: true);
      await server.start();
      final repository = _repositoryFor(server);

      try {
        await repository.connect(host: server.host, port: server.port);
        final status = await repository.getLicenseStatus();

        expect(status?.status.name, 'locked');
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(await repository.isConnected(), isTrue);
        expect(server.websocketConnectionCount, 1);
        expect(server.receivedCommands, contains('LICENSE_STATUS'));
        expect(server.httpDataRequestCount, 0);
      } finally {
        await repository.disconnect();
        await server.close();
      }
    },
  );

  test(
    'D. telemetry is withheld while the authoritative status is LOCKED',
    () async {
      final server = _ModuleServer(
        replyToStatus: true,
        sendPeriodicTelemetry: true,
        httpDataStatus: 200,
        httpDataBody: _activeTelemetry,
      );
      await server.start();
      final repository = _repositoryFor(server);
      final readings = <dynamic>[];
      final subscription = repository.liveUpdates.listen(readings.add);

      try {
        await repository.connect(host: server.host, port: server.port);
        final status = await repository.getLicenseStatus();

        expect(status?.status.name, 'locked');
        // connect() emits the intentional initial disconnected transition
        // before opening the socket. Ignore that neutral event; this assertion
        // is about real telemetry after the LOCKED reply.
        readings.clear();
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(readings, isEmpty);
        expect(repository.hasAuthoritativeActiveLicense, isFalse);
      } finally {
        await subscription.cancel();
        await repository.disconnect();
        await server.close();
      }
    },
  );

  test(
    'E. telemetry starts only after an authoritative ACTIVE status',
    () async {
      final server = _ModuleServer(
        replyToStatus: true,
        licenseStatus: 'ACTIVE',
        licenseType: 'PERMANENT',
        sendPeriodicTelemetry: true,
      );
      await server.start();
      final repository = _repositoryFor(server);
      final readings = <dynamic>[];
      final subscription = repository.liveUpdates.listen(readings.add);

      try {
        await repository.connect(host: server.host, port: server.port);
        final status = await repository.getLicenseStatus();

        expect(status?.status.name, 'active');
        await _waitUntil(
          () => readings.isNotEmpty,
          timeout: const Duration(seconds: 2),
        );
        expect(repository.hasAuthoritativeActiveLicense, isTrue);
      } finally {
        await subscription.cancel();
        await repository.disconnect();
        await server.close();
      }
    },
  );

  test(
    'F. LICENSE_RESULT proof-of-life prevents a telemetry watchdog reconnect',
    () async {
      final server = _ModuleServer(
        replyToActivation: true,
        replyToStatus: true,
      );
      await server.start();
      final repository = _repositoryFor(server);

      try {
        await repository.connect(host: server.host, port: server.port);
        final result = await repository.activateLicense('TEST-CODE');

        expect(result?.ok, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 500));

        expect(await repository.isConnected(), isTrue);
        expect(server.websocketConnectionCount, 1);
        expect(server.receivedCommands, contains('LICENSE_ACTIVATE'));
        expect(server.httpDataRequestCount, 0);
      } finally {
        await repository.disconnect();
        await server.close();
      }
    },
  );

  test('G. a stalled WebSocket still follows the reconnect path', () async {
    final server = _ModuleServer(
      sendInitialTelemetry: true,
      httpDataStatus: 403,
    );
    await server.start();
    final repository = _repositoryFor(server);

    try {
      await repository.connect(host: server.host, port: server.port);
      await _waitForConnected(repository);
      await _waitUntil(
        () => server.websocketConnectionCount >= 2,
        timeout: const Duration(seconds: 3),
      );

      expect(server.websocketConnectionCount, greaterThanOrEqualTo(2));
    } finally {
      await repository.disconnect();
      await server.close();
    }
  });

  test('H. active HTTP fallback still accepts real telemetry', () async {
    final server = _ModuleServer(
      replyToStatus: true,
      licenseStatus: 'ACTIVE',
      licenseType: 'PERMANENT',
      httpDataStatus: 200,
      httpDataBody: _activeTelemetry,
    );
    await server.start();
    final repository = _repositoryFor(server);

    try {
      await repository.connect(host: server.host, port: server.port);
      final status = await repository.getLicenseStatus();
      expect(status?.status.name, 'active');

      final readings = <dynamic>[];
      final subscription = repository.liveUpdates.listen(readings.add);
      try {
        // With an ACTIVE proof and a quiet WebSocket, the existing watchdog
        // path may use HTTP as the transport without bypassing the license
        // boundary.
        await _waitUntil(
          () => server.httpDataRequestCount > 0,
          timeout: const Duration(seconds: 2),
        );

        expect(server.httpDataRequestCount, greaterThan(0));
        expect(readings, isNotEmpty);
        expect(await repository.isConnected(), isTrue);
        expect(server.websocketConnectionCount, greaterThanOrEqualTo(1));
      } finally {
        await subscription.cancel();
      }
    } finally {
      await repository.disconnect();
      await server.close();
    }
  });
}
