import 'dart:async';

import 'package:car_guard/core/models/device_data.dart';
import 'package:car_guard/core/services/http_service.dart';
import 'package:car_guard/core/services/websocket_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_data.dart' as feature_models;
import '../services/device_http_service.dart';
import '../services/device_websocket_service.dart';

/// Repository contract for device communication.
///
/// The public API is intentionally narrow and transport-agnostic so the
/// firmware contract can evolve without forcing UI or feature code to change.
abstract class DeviceRepository {
  /// Connects to the device using the available transports.
  Future<void> connect();

  /// Disconnects from the device and closes transport resources.
  Future<void> disconnect();

  /// Returns whether the device is currently reachable through either transport.
  Future<bool> isConnected();

  /// Reads a JSON payload from the device using the provided endpoint.
  Future<Map<String, dynamic>> readJson({required String endpoint});

  /// Sends a JSON payload to the device using the provided endpoint.
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  });

  /// Receives live device updates as a stream of device data models.
  Stream<DeviceData> receiveLiveUpdates();

  /// Reconnects to the device after a failure or disconnect.
  Future<void> reconnect();

  /// Reads the current device status.
  Future<feature_models.DeviceStatus> getDeviceStatus();

  /// Reads sensor data.
  Future<feature_models.SensorData> readSensorData();

  /// Reads battery data.
  Future<feature_models.BatteryData> readBatteryData();

  /// Reads temperature data.
  Future<feature_models.TemperatureData> readTemperatureData();

  /// Reads coolant level data.
  Future<feature_models.CoolantLevelData> readCoolantLevelData();
}

/// Repository implementation that coordinates request/response and streaming
/// transports without introducing UI or firmware-specific behavior.
class DeviceRepositoryImpl implements DeviceRepository {
  /// Creates a repository implementation backed by transport abstractions.
  DeviceRepositoryImpl({
    required this._commandTransport,
    required this._streamTransport,
  }) {
    _attachLiveUpdates();
  }

  final DeviceTransport _commandTransport;
  final DeviceStreamTransport _streamTransport;
  final StreamController<DeviceData> _liveDataController =
      StreamController<DeviceData>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _liveSubscription;

  void _attachLiveUpdates() {
    if (_liveSubscription != null) {
      return;
    }

    _liveSubscription = _streamTransport.receiveLiveUpdates().listen(
      (payload) {
        if (_liveDataController.isClosed) {
          return;
        }

        try {
          _liveDataController.add(_decodeDeviceData(payload));
        } on FormatException catch (error) {
          _liveDataController.addError(error);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_liveDataController.isClosed) {
          _liveDataController.addError(error, stackTrace);
        }
      },
      onDone: () {
        if (!_liveDataController.isClosed) {
          _liveDataController.close();
        }
      },
    );
  }

  DeviceData _decodeDeviceData(Map<String, dynamic> payload) {
    return DeviceData.fromJson(payload);
  }

  @override
  Future<void> connect() async {
    await _commandTransport.connect();
    await _streamTransport.connect();
    _attachLiveUpdates();
  }

  @override
  Future<void> disconnect() async {
    await _streamTransport.disconnect();
    await _commandTransport.disconnect();
    await _liveSubscription?.cancel();
    _liveSubscription = null;
  }

  @override
  Future<bool> isConnected() async {
    final commandConnected = await _commandTransport.isConnected();
    final streamConnected = await _streamTransport.isConnected();
    return commandConnected || streamConnected;
  }

  @override
  Future<Map<String, dynamic>> readJson({required String endpoint}) {
    return _commandTransport.readJson(endpoint: endpoint);
  }

  @override
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) {
    return _commandTransport.sendJson(endpoint: endpoint, payload: payload);
  }

  @override
  Stream<DeviceData> receiveLiveUpdates() => _liveDataController.stream;

  @override
  Future<void> reconnect() async {
    await _commandTransport.reconnect();
    await _streamTransport.reconnect();
  }

  @override
  Future<feature_models.DeviceStatus> getDeviceStatus() async =>
      const feature_models.DeviceStatus();

  @override
  Future<feature_models.SensorData> readSensorData() async =>
      const feature_models.SensorData();

  @override
  Future<feature_models.BatteryData> readBatteryData() async =>
      const feature_models.BatteryData();

  @override
  Future<feature_models.TemperatureData> readTemperatureData() async =>
      const feature_models.TemperatureData();

  @override
  Future<feature_models.CoolantLevelData> readCoolantLevelData() async =>
      const feature_models.CoolantLevelData();
}

/// Placeholder transport implementation used until a concrete device transport
/// is available from the firmware contract.
class PlaceholderDeviceTransport implements DeviceTransport {
  @override
  Future<void> connect({String? endpoint}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isConnected() async => false;

  @override
  Future<Map<String, dynamic>> readJson({required String endpoint}) async {
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> sendJson({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    return <String, dynamic>{};
  }

  @override
  Stream<Map<String, dynamic>> receiveLiveUpdates() => const Stream.empty();

  @override
  Future<void> reconnect() async {}
}

/// Riverpod provider for injecting the repository into the app.
final deviceTransportProvider = Provider<DeviceTransport>(
  (ref) => PlaceholderDeviceTransport(),
);

/// Riverpod provider for exposing the HTTP transport implementation.
final httpDeviceTransportProvider = Provider<DeviceTransport>((ref) {
  final httpService = ref.watch(httpServiceProvider);
  return HttpDeviceTransport(httpService: httpService);
});

/// Riverpod provider for exposing the WebSocket transport implementation.
final webSocketDeviceTransportProvider = Provider<DeviceStreamTransport>((ref) {
  final webSocketService = ref.watch(webSocketServiceProvider);
  return WebSocketDeviceTransport(webSocketService: webSocketService);
});

/// Riverpod provider for exposing the repository contract.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final commandTransport = ref.watch(httpDeviceTransportProvider);
  final streamTransport = ref.watch(webSocketDeviceTransportProvider);
  return DeviceRepositoryImpl(
    commandTransport: commandTransport,
    streamTransport: streamTransport,
  );
});
