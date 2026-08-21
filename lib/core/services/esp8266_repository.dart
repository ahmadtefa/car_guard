import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/device_endpoints.dart';
import 'device_models.dart';
import 'device_repository.dart';
import 'mdns_discovery_service.dart';
import 'network_binding_service.dart';


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

  /// Last settings the module itself reported (`/getallsettings`). Used to
  /// fill limits the firmware does not stream, so voltage/temperature
  /// alerts keep working on every hardware build. When even that fails the
  /// firmware defaults (95 °C / 12.0 V / 15.0 V — the same values the
  /// module itself ships with) are used, so an unreadable module never
  /// silently disables its own alarms.
  DeviceModuleSettings? _lastModuleSettings;
  bool _moduleLimitsRequested = false;

  /// SharedPreferences key holding the cached module settings JSON so the
  /// background monitor isolate can use the same fallback.
  static const String moduleLimitsCacheKey = 'module_limits_cache';

  /// Keys for the optional direct Wi-Fi pairing (WifiNetworkSpecifier) stored
  /// by the settings page through [StorageServiceImpl] (prefix `flutter.`).
  static const String pairingEnabledKey = 'wifi_direct_pairing';
  static const String pairingSsidKey = 'wifi_direct_pairing_ssid';
  static const String pairingPassKey = 'wifi_direct_pairing_password';

  /// Last address discovered by mDNS for car_guard.local — reused by the
  /// Android Auto screen and the background monitor when the saved/default
  /// address does not answer.
  static const String lastModuleIpKey = 'mdns_module_ip';

  DateTime? _lastMdnsLookup;

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

    // Optional direct, app-scoped pairing (paired from Settings -> Device
    // connection): keeps the module reachable while 4G stays the phone's
    // internet route without any system dialog.
    await _maybePairModuleWifi();

    // Pin this app's traffic to the module's Wi-Fi network: the module keeps
    // streaming while the phone's internet keeps riding mobile data (4G).
    await NetworkBindingService.bindToModuleWifi();

    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _wsReconnectAttempts = 0;

    // [STA+mDNS] When the module joined the phone hotspot / home router, it
    // announces itself as car_guard.local — resolve that once and follow it,
    // so a DHCP-assigned IP never needs to be typed by hand. Throttled: at
    // most one lookup per minute (WS reconnects call connect() repeatedly).
    if (_lastMdnsLookup == null ||
        DateTime.now().difference(_lastMdnsLookup!) >
            const Duration(minutes: 1)) {
      _lastMdnsLookup = DateTime.now();

      final discovered = await MdnsDiscoveryService().resolveModuleIp();

      if (discovered != null &&
          discovered.isNotEmpty &&
          discovered != host) {
        debugPrint("MDNS SWITCH $host -> $discovered");
        host = discovered;
        _activeHost = discovered;

        // Persist for the other readers of the connection target
        // (Android Auto screen + background monitor).
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(lastModuleIpKey, discovered);
      }
    }


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


      try {

        _channel!.sink.add(
          "hello",
        );

      } catch (e) {

        // Writing to a freshly-closed socket throws; the onDone/onError
        // handlers take over from here.

        debugPrint(
          "WS HELLO FAILED $e",
        );

      }


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

      final settings = DeviceModuleSettings.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      _cacheModuleLimits(settings);

      return settings;

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

    final ok = await _getExpectsOk(
      "${DeviceEndpoints.saveAllSettings}"
      "?maxTemp=${settings.maxTemp}"
      "&fanOnTemp=${settings.fanOnTemp}"
      "&minVolt=${settings.minVolt}"
      "&maxVolt=${settings.maxVolt}"
      "&offset=${settings.offset}",
    );

    if (ok) {
      _cacheModuleLimits(settings);
    }

    return ok;

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



  /// Uploads a firmware image to the module OTA page (`/update`).
  ///
  /// The multipart field name matches ESP8266HTTPUpdateServer's form
  /// ('firmware'). The module flashes and reboots on success.
  Future<bool> updateFirmware(String filePath) async {

    try {

      final uri = Uri.parse(
        "http://$_activeHost${DeviceEndpoints.otaUpdate}",
      );

      final request = http.MultipartRequest("POST", uri)
        ..files.add(await http.MultipartFile.fromPath("firmware", filePath));

      final response = await request
          .send()
          .timeout(const Duration(seconds: 120));

      return response.statusCode == 200;

    } catch (e) {

      debugPrint(
        "OTA UPLOAD FAILED : $e",
      );

      return false;

    }

  }



  /// Reads the Wi-Fi credentials stored on the module
  /// (`/getwifisettings`).
  Future<({String ssid, String password})?> getWifiSettings() async {

    try {

      final response = await http
          .get(
            Uri.parse(
              "http://$_activeHost${DeviceEndpoints.getWifiSettings}",
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

      return (
        ssid: decoded['ssid'] as String? ?? '',
        password: decoded['password'] as String? ?? '',
      );

    } catch (e) {

      debugPrint(
        "GET WIFI SETTINGS FAILED : $e",
      );

      return null;

    }

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



  /// [STA+mDNS] Tells the module to join another network (phone hotspot or
  /// home router) in addition to its own AP (`/joinwifi`). The credentials
  /// persist on the module, so it re-joins by itself after every boot and
  /// mDNS lets the app find it back automatically.
  Future<bool> joinExternalWifi({
    required String ssid,
    required String password,
  }) async {

    return _getExpectsOk(
      "${DeviceEndpoints.joinWifi}"
      "?ssid=${Uri.encodeComponent(ssid)}"
      "&pass=${Uri.encodeComponent(password)}",
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

    _ensureModuleLimitsLoaded();

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
        ).fillFrom(_lastModuleSettings ?? const DeviceModuleSettings());

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

            muted:
                json["muted"] == 1 ||
                json["muted"] == true,

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

            // temp,volt,fanState,?,...,offset,alarm,muted
            buzzerActive:
                parts.length > 9 ? parts[9].trim() == "1" : false,

            muted: parts.length > 10 ? parts[10].trim() == "1" : false,

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

          ).fillFrom(_lastModuleSettings ?? const DeviceModuleSettings()),


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

    // Release the Wi-Fi binding so the app follows the system network again.
    unawaited(NetworkBindingService.bindToDefault());

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


  /// If the user enabled direct pairing in Settings, asks Android for an
  /// app-scoped link to the module network (WifiNetworkSpecifier) so the
  /// phone keeps 4G as its internet route without any system dialog.
  Future<void> _maybePairModuleWifi() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getString(pairingEnabledKey) != 'true') return;

      final ssid = prefs.getString(pairingSsidKey) ?? '';
      final password = prefs.getString(pairingPassKey) ?? '';
      if (ssid.isEmpty) return;

      debugPrint('DIRECT PAIRING REQUEST -> $ssid');

      await NetworkBindingService.pairWithModuleWifi(
        ssid: ssid,
        password: password,
      );
    } catch (e) {
      debugPrint('WIFI PAIRING READ FAILED: $e');
    }
  }

  /// Remembers the limits the module reported, and persists them so the
  /// background monitor isolate can fall back to the same values.
  void _cacheModuleLimits(DeviceModuleSettings settings) {
    _lastModuleSettings = settings;

    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          moduleLimitsCacheKey,
          jsonEncode(settings.toJson()),
        );
      } catch (_) {
        // Best-effort cache only — the live stream stays authoritative.
      }
    }());
  }


  /// Fetches `/getallsettings` once after the first valid reading so the
  /// module-borne limits are known even when the live stream omits them.
  /// Falls back to the persisted cache when the module can't answer yet.
  void _ensureModuleLimitsLoaded() {
    if (_moduleLimitsRequested) return;
    _moduleLimitsRequested = true;

    unawaited(() async {
      final fetched = await getDeviceSettings();
      if (fetched != null || _lastModuleSettings != null) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(moduleLimitsCacheKey);

        if (raw != null && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            _lastModuleSettings = DeviceModuleSettings.fromJson(
              Map<String, dynamic>.from(decoded),
            );
          }
        }
      } catch (_) {
        // No cache — sensor alerts wait until the module can be read.
      }
    }());
  }

}