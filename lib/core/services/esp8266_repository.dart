import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'device_models.dart';
import 'device_repository.dart';


class Esp8266Repository implements DeviceRepository {
  Esp8266Repository({
    required this.host,
    this.port = 81,
  }) : _activeHost = host,
       _activePort = port;

  final String host;
  final int port;

  String _activeHost;
  int _activePort;

  WebSocketChannel? _channel;
  Timer? _httpTimer;

  final StreamController<DeviceStatus> _statusController =
      StreamController<DeviceStatus>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _connected = false;
  bool _usingHttpFallback = false;

  Stream<bool> get connectionStream =>
      _connectionController.stream;


  @override
  Future<void> connect({
    required String host,
    int? port,
  }) async {

    final wsPort = port ?? this.port;
    _activeHost = host;
    _activePort = wsPort;

    await disconnect();


    debugPrint(
      "TRY WEBSOCKET ws://$host:$wsPort",
    );


    try {

      _channel = WebSocketChannel.connect(
        Uri.parse(
          "ws://$host:$wsPort",
        ),
      );


      _channel!.stream.listen(

        (message) {

          debugPrint(
            "WS DATA = $message",
          );


          _connected = true;
          _usingHttpFallback = false;

          _connectionController.add(true);


          _handleData(
            message.toString(),
          );

        },


        onDone: () {

          debugPrint(
            "WS CLOSED",
          );

          _setDisconnected();

          _startHttpFallback(host);

        },


        onError: (error) {

          debugPrint(
            "WS ERROR $error",
          );

          _setDisconnected();

          _startHttpFallback(host);

        },


        cancelOnError: true,

      );


      _channel!.sink.add(
        "hello",
      );


      Future.delayed(
        const Duration(seconds: 3),
        () {

          if (!_connected) {

            debugPrint(
              "WS TIMEOUT -> HTTP FALLBACK",
            );

            _startHttpFallback(host);

          }

        },
      );


    } catch (e) {

      debugPrint(
        "WS CONNECT FAILED $e",
      );

      _setDisconnected();

      _startHttpFallback(host);

    }

  }



  void _startHttpFallback(
    String host,
  ) {

    if (_usingHttpFallback) {
      return;
    }


    debugPrint(
      "START HTTP FALLBACK",
    );


    _usingHttpFallback = true;


    _httpTimer?.cancel();


    _httpTimer = Timer.periodic(

      const Duration(seconds: 1),

      (_) async {

        try {

          final response =
              await http.get(

            Uri.parse(
              "http://$host/data",
            ),

          );


          if (response.statusCode == 200) {


            debugPrint(
              "HTTP DATA = ${response.body}",
            );


            _connected = true;

            _connectionController.add(true);


            _handleData(
              response.body,
            );


          }


        } catch (e) {


          debugPrint(
            "HTTP ERROR $e",
          );


          _setDisconnected();


        }

      },

    );

  }



  void _setDisconnected() {

    _connected = false;

    _connectionController.add(false);

    _statusController.add(DeviceStatus.disconnected());

  }




  void _handleData(
    String data,
  ) {

    try {

      DeviceStatus status;


      if (data.trim().startsWith('{')) {

        final json =
            jsonDecode(data);


        status = DeviceStatus(

          connected: true,

          deviceId: "Car Guard",


          batteryData: BatteryData(

            voltage:
                (json["volt"] as num)
                    .toDouble(),

            voltageDifference:
                (json["voltDiff"] as num?)?.toDouble() ??
                (json["voltageDifference"] as num?)?.toDouble() ??
                0.0,

          ),


          temperatureData: TemperatureData(

            engineTemperature:
                (json["temp"] as num)
                    .toDouble(),

          ),


          coolantLevelData:
              const CoolantLevelData(


            coolantAvailable: true,


          ),


          controlData: DeviceControlData(

            fanRunning:
                json["fanState"] == 1,

            buzzerActive:
                json["buzzerState"] == 1 ||
                json["buzzerActive"] == true ||
                json["alarm"] == 1 ||
                json["alarmState"] == 1,

          ),


          lastUpdated:
              DateTime.now(),

        );


      } else {


        final parts =
            data.split(',');


        if (parts.length < 4) {

          debugPrint(
            "INVALID WS DATA",
          );

          return;

        }


        status = DeviceStatus(

          connected: true,

          deviceId: "Car Guard",


          batteryData: BatteryData(

            voltage:
                double.parse(
                  parts[1],
                ),

            voltageDifference:
                parts.length > 5 ? (double.tryParse(parts[5]) ?? 0.0) : 0.0,

          ),


          temperatureData:
              TemperatureData(

            engineTemperature:
                double.parse(
                  parts[0],
                ),

          ),


          coolantLevelData:
              CoolantLevelData(

            coolantAvailable:
                parts[2] == "1",

          ),


          controlData:
              DeviceControlData(

            fanRunning:
                parts[3] == "1",

            buzzerActive:
                parts.length > 4 ? parts[4].trim() == "1" : false,

          ),


          lastUpdated:
              DateTime.now(),

        );

      }


      _statusController.add(
        status,
      );


    } catch (e) {


      debugPrint(
        "DATA PARSE ERROR : $e",
      );


      debugPrint(
        data,
      );


    }

  }




  @override
  Future<void> disconnect() async {


    _httpTimer?.cancel();

    _httpTimer = null;


    await _channel?.sink.close();


    _channel = null;


    _connected = false;

    _usingHttpFallback = false;


    _connectionController.add(false);

    _statusController.add(DeviceStatus.disconnected());

  }




  @override
  Future<bool> isConnected() async {

    return _connected;

  }




  @override
  Future<Map<String, dynamic>> readJson() async {

    return {};

  }




  @override
  Future<void> sendJson(
    Map<String, dynamic> payload,
  ) async {


    if (_channel != null) {


      _channel!.sink.add(
        jsonEncode(payload),
      );


      return;

    }



    try {


      await http.post(

        Uri.parse(
          "http://$_activeHost/data",
        ),


        headers: const {

          "Content-Type":
              "application/json",

        },


        body:
            jsonEncode(payload),

      );


    } catch (e) {


      debugPrint(
        "HTTP SEND ERROR $e",
      );


    }

  }




  @override
  Stream<DeviceStatus> get liveUpdates =>
      _statusController.stream;



  @override
  Future<void> reconnect() async {

    await connect(
      host: _activeHost,
      port: _activePort,
    );

  }

}