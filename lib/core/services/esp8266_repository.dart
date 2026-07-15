import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _connected = false;

  Stream<bool> get connectionStream =>
      _connectionController.stream;

  @override
  Future<void> connect({required String host, int? port}) async {
    final wsPort = port ?? this.port;

    await disconnect();

    debugPrint("CONNECTING TO ws://$host:$wsPort");

    _channel = WebSocketChannel.connect(
      Uri.parse("ws://$host:$wsPort"),
    );

    _connected = true;
    _connectionController.add(true);

    _channel!.stream.listen(
      (message) {
        debugPrint("WS MESSAGE FROM ESP = $message");

        try {
          final parts = message.toString().split(',');

          if (parts.length < 4) {
            debugPrint("INVALID MESSAGE");
            return;
          }

          final status = DeviceStatus(
            connected: true,
            deviceId: "ESP8266",

            batteryData: BatteryData(
              voltage: double.parse(parts[1]),
            ),

            temperatureData: TemperatureData(
              engineTemperature: double.parse(parts[0]),
            ),

            coolantLevelData: CoolantLevelData(
              coolantAvailable: parts[2] == "1",
            ),

            controlData: DeviceControlData(
              fanRunning: parts[3] == "1",
              buzzerActive: false,
            ),

            lastUpdated: DateTime.now(),
          );

          _statusController.add(status);

        } catch (e) {
          debugPrint(e.toString());
        }
      },

      onDone: () {
        debugPrint("WS CLOSED");
        _connected = false;
        _connectionController.add(false);
      },

      onError: (e) {
        debugPrint("WS ERROR");
        debugPrint(e.toString());
        _connected = false;
        _connectionController.add(false);
      },
    );

    _channel!.sink.add("hello");
  }


  @override
  Future<void> disconnect() async {
    await _channel?.sink.close();

    _channel = null;

    _connected = false;
    _connectionController.add(false);
  }


  @override
  Future<bool> isConnected() async =>
      _connected;


  @override
  Future<Map<String, dynamic>> readJson() async =>
      {};


  @override
  Future<void> sendJson(
      Map<String, dynamic> payload) async {
    _channel?.sink.add(
      jsonEncode(payload),
    );
  }


  @override
  Stream<DeviceStatus> get liveUpdates =>
      _statusController.stream;


  @override
  Future<void> reconnect() async {
    await connect(
      host: host,
      port: port,
    );
  }
}