import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/device_endpoints.dart';
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
  Timer? _wsTimeoutTimer;

  final StreamController<DeviceStatus> _statusController =
      StreamController<DeviceStatus>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _connected = false;
  bool _usingHttpFallback = false;

  int _wsReconnectAttempts = 0;
  Timer? _wsReconnectTimer;
  static const int _maxWsReconnectAttempts = 10;

  /// True while the repository is intentionally torn down; prevents the
  /// WebSocket onDone/onError callbacks from restarting the HTTP fallback
  /// after [disconnect] already cancelled every timer.
  bool _stopped = true;

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

    // disconnect() flagged the repository as stopped; clear the flag because
    // connect() is about to establish a brand new session.
    _stopped = false;

    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _wsReconnectAttempts = 0;


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

          if (_wsReconnectAttempts != 0) {
            _wsReconnectAttempts = 0;
          }

          _wsReconnectTimer?.cancel();
          _wsReconnectTimer = null;

          _connectionController.add(true);


          _handleData(
            message.toString(),
          );

        },


        onDone: () {

          debugPrint(
            "WS CLOSED",
          );

          if (_stopped) {
            return;
          }

          _setDisconnected();

          _startHttpFallback(host);

          _scheduleWsReconnect();


        },


        onError: (error) {

          debugPrint(
            "WS ERROR $error",
          );

          if (_stopped) {
            return;
          }

          _setDisconnected();

          _startHttpFallback(host);

          _scheduleWsReconnect();

        },


        cancelOnError: true,

      );


      _channel!.sink.add(
        "hello",
      );


      _wsTimeoutTimer?.cancel();

      _wsTimeoutTimer = Timer(
        const Duration(seconds: 3),
        () {

          if (!_connected && !_stopped) {

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

    if (_stopped || _usingHttpFallback) {
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



  void _scheduleWsReconnect() {

    if (_stopped || _wsReconnectTimer != null) {
      return;
    }

    if (_wsReconnectAttempts >= _maxWsReconnectAttempts) {

      debugPrint(
        "WS RECONNECT GAVE UP - STAYING ON HTTP POLLING",
      );

      return;

    }


    _wsReconnectAttempts++;


    final delaySeconds = 3 * _wsReconnectAttempts.clamp(1, 5);

    debugPrint(
      "WS RECONNECT IN ${delaySeconds}s (attempt $_wsReconnectAttempts/$_maxWsReconnectAttempts)",
    );


    _wsReconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      () {

        _wsReconnectTimer = null;

        if (_stopped || _connected) {
          return;
        }

        connect(
          host: _activeHost,
          port: _activePort,
        );

      },
    );

  }



  void _setDisconnected() {

    _connected = false;

    _connectionController.add(false);

    _statusController.add(DeviceStatus.disconnected());

  }



  /// Sends a raw GET command to the connected module and reports whether it
  /// acknowledged the request.
  Future<bool> sendDeviceCommand(String endpoint) async {

    if (_stopped) {
      return false;
    }


    try {

      final response = await http
          .get(
            Uri.parse("http://$_activeHost$endpoint"),
          )
          .timeout(
            const Duration(seconds: 5),
          );

      return response.statusCode == 200;

    } catch (e) {

      debugPrint(
        "DEVICE COMMAND FAILED $endpoint : $e",
      );

      return false;

    }

  }



  /// Silences the module buzzer (`/mute`).
  Future<bool> muteBuzzer() => sendDeviceCommand(DeviceEndpoints.mute);

  /// Runs the radiator fan test (`/testfan`).
  Future<bool> testFan() => sendDeviceCommand(DeviceEndpoints.testFan);

  /// Reboots the module (`/restart`).
  Future<bool> restartDevice() => sendDeviceCommand(DeviceEndpoints.restart);


  /// Fetches the settings stored on the module (`/getallsettings`).
  ///
  /// Returns null when the device is unreachable or replies with an
  /// unexpected payload.
  Future<DeviceModuleSettings?> getDeviceSettings() async {

    try {

      final response = await http
          .get(
            Uri.parse(
              "http://$_activeHost${DeviceEndpoints.getAllSettings}",
            ),
          )
          .timeout(
            const Duration(seconds: 5),
          );


      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      return DeviceModuleSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );

    } catch (e) {

      debugPrint(
        "GET DEVICE SETTINGS FAILED : $e",
      );

      return null;

    }

  }



  /// Saves alarm limits to the module (`/saveallsettings`).
  Future<bool> saveDeviceSettings(
    DeviceModuleSettings settings,
  ) async {

    return _getExpectsOk(
      "${DeviceEndpoints.saveAllSettings}"
      "?maxTemp=${settings.maxTemp}"
      "&fanOnTemp=${settings.fanOnTemp}"
      "&minVolt=${settings.minVolt}"
      "&maxVolt=${settings.maxVolt}"
      "&offset=${settings.offset}",
    );

  }



  /// Saves calibration values to the module (`/saveadvancedsettings`).
  Future<bool> saveAdvancedSettings(DeviceModuleSettings settings) async {

    return _getExpectsOk(
      "${DeviceEndpoints.saveAdvancedSettings}"
      "?offset=${settings.offset}"
      "&voltCalib=${settings.voltCalib}"
      "&r1=${settings.r1}"
      "&r2=${settings.r2}"
      "&sensorPullUp=${settings.sensorPullUp}"
      "&installDate=${Uri.encodeComponent(settings.installDate)}",
    );

  }



  /// Runs the on-module voltage calibration wizard (`/calibratevoltage`).
  ///
  /// The firmware replies with `OK,<newFactor>`; the new factor is returned
  /// so the caller can refresh the calibration field, or null on failure.
  Future<double?> calibrateVoltage(double realVolt) async {

    try {

      final response = await http
          .get(
            Uri.parse(
              "http://$_activeHost${DeviceEndpoints.calibrateVoltage}"
              "?realVolt=$realVolt",
            ),
          )
          .timeout(
            const Duration(seconds: 6),
          );


      final body = response.body.trim();

      if (response.statusCode != 200 ||
          !body.toUpperCase().startsWith("OK")) {
        return null;
      }

      final parts = body.split(",");

      if (parts.length < 2) {
        return null;
      }

      return double.tryParse(parts[1].trim());

    } catch (e) {

      debugPrint(
        "CALIBRATE VOLTAGE FAILED : $e",
      );

      return null;

    }

  }



  /// Provisions the module Wi-Fi (`/savewifi`).
  ///
  /// The module usually restarts its access point right after replying, so a
  /// network failure after the request was sent is expected.
  Future<bool> saveWifiSettings({
    required String ssid,
    required String password,
  }) async {

    return _getExpectsOk(
      "${DeviceEndpoints.saveWifiSettings}"
      "?ssid=${Uri.encodeComponent(ssid)}"
      "&password=${Uri.encodeComponent(password)}",
    );

  }



  Future<bool> _getExpectsOk(String pathAndQuery) async {

    try {

      final response = await http
          .get(
            Uri.parse("http://$_activeHost$pathAndQuery"),
          )
          .timeout(
            const Duration(seconds: 8),
          );

      return response.statusCode == 200 &&
          response.body.trim().toUpperCase() == "OK";

    } catch (e) {

      debugPrint(
        "DEVICE REQUEST FAILED $pathAndQuery : $e",
      );

      return false;

    }

  }




  void _handleData(
    String data,
  ) {

    try {

      DeviceStatus status;


      if (data.trim().startsWith('{')) {

        final json =
            jsonDecode(data);

        // Coolant may arrive as 1/0, "1"/"0" or true/false depending on the
        // firmware revision; when the key is absent we optimistically assume
        // coolant is available instead of crying wolf.
        final rawCoolant = json["coolant"] ?? json["coolantAvailable"];

        final coolantAvailable = rawCoolant == null ||
            rawCoolant == 1 ||
            rawCoolant == '1' ||
            rawCoolant == true;

        final moduleLimits = ModuleLimits(
          maxTemp: (json["maxTemp"] as num?)?.toDouble(),
          fanOnTemp: (json["fanOnTemp"] as num?)?.toDouble(),
          minVolt: (json["minVolt"] as num?)?.toDouble(),
          maxVolt: (json["maxVolt"] as num?)?.toDouble(),
          offset: (json["offset"] as num?)?.toDouble(),
        );

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
              CoolantLevelData(


            coolantAvailable: coolantAvailable,


          ),


          controlData: DeviceControlData(

            fanRunning:
                json["fanState"] == 1 ||
                json["fanState"] == true,

            buzzerActive:
                json["buzzerState"] == 1 ||
                json["buzzerActive"] == true ||
                json["alarm"] == 1 ||
                json["alarmState"] == 1,

          ),


          moduleLimits: moduleLimits,


          lastUpdated:
              DateTime.now(),

        );


      } else {


        final parts =
            data.split(',');


        if (parts.length < 3) {

          debugPrint(
            "INVALID WS DATA",
          );

          return;

        }


        // Reference protocol (from the original Kayan dashboard):
        // temp,volt,fanState,?,maxTemp,fanOnTemp,minVolt,maxVolt,offset
        status = DeviceStatus(

          connected: true,

          deviceId: "Car Guard",


          batteryData: BatteryData(

            voltage:
                double.tryParse(
                  parts[1].trim(),
                ) ??
                0.0,

          ),


          temperatureData:
              TemperatureData(

            engineTemperature:
                double.tryParse(
                  parts[0].trim(),
                ) ??
                0.0,

          ),


          coolantLevelData:
              const CoolantLevelData(

            coolantAvailable: true,

          ),


          controlData:
              DeviceControlData(

            fanRunning:
                parts[2].trim() == "1" ||
                    parts[2].trim().toLowerCase() == "true",

            buzzerActive: false,

          ),


          moduleLimits: ModuleLimits(

            maxTemp: parts.length > 4
                ? double.tryParse(parts[4].trim())
                : null,

            fanOnTemp: parts.length > 5
                ? double.tryParse(parts[5].trim())
                : null,

            minVolt: parts.length > 6
                ? double.tryParse(parts[6].trim())
                : null,

            maxVolt: parts.length > 7
                ? double.tryParse(parts[7].trim())
                : null,

            offset: parts.length > 8
                ? double.tryParse(parts[8].trim())
                : null,

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

    // Flag first so the WebSocket onDone/onError callbacks triggered by
    // closing the sink below cannot restart the HTTP fallback timer.
    _stopped = true;

    _httpTimer?.cancel();

    _httpTimer = null;

    _wsTimeoutTimer?.cancel();

    _wsTimeoutTimer = null;

    _wsReconnectTimer?.cancel();

    _wsReconnectTimer = null;

    _wsReconnectAttempts = 0;

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