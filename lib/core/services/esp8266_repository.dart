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
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _httpTimer;
  Timer? _watchdogTimer;

  final StreamController<DeviceStatus> _statusController =
      StreamController<DeviceStatus>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _connected = false;
  bool _usingHttpFallback = false;
  bool _httpRequestInFlight = false;
  bool _connectAttemptInProgress = false;

  /// Monotonic token identifying the latest connect attempt, so delayed
  /// callbacks from an older attempt never affect a newer one.
  int _connectAttemptCounter = 0;

  /// Stays true while an active connection is wanted (set by [connect]).
  /// A manual [disconnect] clears it so automatic recovery paths
  /// (watchdog, network callbacks) never reconnect behind the user's back.
  bool _autoReconnectEnabled = false;

  /// A dead TCP connection (WiFi toggled off, device powered down) never
  /// delivers a close frame, so the only reliable symptom is silence.
  /// If no data arrives for this long while we believe we are connected,
  /// the link is treated as lost.
  static const Duration _watchdogTimeout = Duration(seconds: 6);

  /// WebSocket protocol level keep-alive. dart:io sends pings on this
  /// interval and closes the connection when no pong comes back, which
  /// makes the stream fire its onDone/onError handlers even on dead links.
  static const Duration _wsPingInterval = Duration(seconds: 5);

  /// Hard timeout for plain HTTP calls so a dead device reports in seconds
  /// instead of waiting for the operating system TCP timeout (minutes).
  static const Duration _httpTimeout = Duration(seconds: 3);

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

    await _closeTransport();

    _autoReconnectEnabled = true;
    _connectAttemptInProgress = true;


    debugPrint(
      "TRY WEBSOCKET ws://$host:$wsPort",
    );


    try {

      final channel = WebSocketChannel.connect(
        Uri.parse(
          "ws://$host:$wsPort",
        ),
        pingInterval: _wsPingInterval,
      );

      _channel = channel;


      _channelSubscription = channel.stream.listen(

        (message) {

          debugPrint(
            "WS DATA = $message",
          );


          // Only genuine device telemetry may keep the connection alive:
          // on a foreign network some other service could answer on the
          // device IP, and its garbage must not fake a live link.
          final valid = _handleData(
            message.toString(),
          );

          if (!valid) {
            return;
          }


          _connected = true;
          _connectAttemptInProgress = false;
          _stopHttpFallback();

          _connectionController.add(true);

          _resetWatchdog();

        },


        onDone: () {

          debugPrint(
            "WS CLOSED",
          );

          _handleTransportDown(host);

        },


        onError: (error) {

          debugPrint(
            "WS ERROR $error",
          );

          _handleTransportDown(host);

        },


        cancelOnError: true,

      );


      _channel!.sink.add(
        "hello",
      );


      // Data is expected to keep flowing from the device; total silence
      // right after connecting means the link never really came up.
      _resetWatchdog();


      final attempt = ++_connectAttemptCounter;

      Future.delayed(
        const Duration(seconds: 3),
        () {

          if (attempt != _connectAttemptCounter) {
            // A newer connect attempt replaced this one.
            return;
          }

          if (!_connected && _connectAttemptInProgress) {

            debugPrint(
              "WS TIMEOUT -> HTTP FALLBACK",
            );

            _connectAttemptInProgress = false;

            if (_autoReconnectEnabled) {
              _startHttpFallback(host);
            }

          }

        },
      );


    } catch (e) {

      debugPrint(
        "WS CONNECT FAILED $e",
      );

      _connectAttemptInProgress = false;

      _setDisconnected();

      if (_autoReconnectEnabled) {
        _startHttpFallback(host);
      }

    }

  }



  /// The WebSocket reported a genuine close or error: mark the connection
  /// as lost and fall back to HTTP polling so the link recovers on its own
  /// as soon as the device answers again.
  void _handleTransportDown(
    String host,
  ) {

    if (_channel == null) {
      // Stale callback from an already replaced connection.
      return;
    }

    _channel = null;
    _channelSubscription = null;
    _connectAttemptInProgress = false;

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _setDisconnected();

    if (_autoReconnectEnabled) {
      _startHttpFallback(host);
    }

  }



  /// Restarts the inactivity watchdog. Called on every piece of data that
  /// actually arrives from the device, no matter which transport served it.
  void _resetWatchdog() {

    _watchdogTimer?.cancel();

    _watchdogTimer = Timer(
      _watchdogTimeout,
      _onWatchdogTimeout,
    );

  }



  /// No data arrived for [_watchdogTimeout] while we believed the link was
  /// up. A dropped network does not close the socket, so probe the device
  /// once over plain HTTP before declaring the connection lost.
  Future<void> _onWatchdogTimeout() async {

    try {

      debugPrint(
        "WATCHDOG TIMEOUT - PROBING DEVICE",
      );


      final alive = await _probeHttp();


      if (alive) {

        // The device still answers over HTTP but the WebSocket went
        // quiet: keep receiving through the fallback transport without
        // dropping the session.
        debugPrint(
          "DEVICE STILL ALIVE VIA HTTP - USING FALLBACK",
        );

        _resetWatchdog();

        if (_autoReconnectEnabled) {
          _startHttpFallback(_activeHost);
        }

        return;

      }


      debugPrint(
        "DEVICE NOT RESPONDING - CONNECTION LOST",
      );


      await _closeTransport();

      _setDisconnected();


      if (_autoReconnectEnabled) {
        _startHttpFallback(_activeHost);
      }


    } catch (e) {

      debugPrint(
        "WATCHDOG ERROR $e",
      );

    }

  }



  /// Single quick HTTP probe used by the watchdog to confirm whether the
  /// device is truly unreachable.
  Future<bool> _probeHttp() async {

    try {

      final response = await http
          .get(
            Uri.parse(
              "http://$_activeHost${DeviceEndpoints.dashboard}",
            ),
          )
          .timeout(_httpTimeout);

      // HTTP 200 alone means nothing on a foreign network; only the
      // device's own telemetry format proves it is really there.
      return response.statusCode == 200 &&
          _parseStatus(response.body) != null;

    } catch (_) {

      return false;

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
    _connectAttemptInProgress = false;

    _httpTimer?.cancel();


    // Poll immediately instead of waiting a full interval first.
    unawaited(_pollHttp(host));


    _httpTimer = Timer.periodic(

      const Duration(seconds: 1),

      (_) => unawaited(_pollHttp(host)),

    );

  }



  void _stopHttpFallback() {

    if (!_usingHttpFallback) {
      return;
    }

    _usingHttpFallback = false;

    _httpTimer?.cancel();
    _httpTimer = null;

  }



  Future<void> _pollHttp(
    String host,
  ) async {

    // Previous request still running (e.g. stuck in its timeout window):
    // skip this tick instead of stacking requests on top of each other.
    if (_httpRequestInFlight) {
      return;
    }

    _httpRequestInFlight = true;


    try {

      final response = await http
          .get(
            Uri.parse(
              "http://$host${DeviceEndpoints.dashboard}",
            ),
          )
          .timeout(_httpTimeout);


      // A bare 200 is not proof of life: the body must parse as real
      // device telemetry, otherwise whatever answered on this network
      // (router page, captive portal, ...) is impersonating the device.
      if (response.statusCode == 200 &&
          _handleData(response.body)) {

        debugPrint(
          "HTTP DATA = ${response.body}",
        );


        _connected = true;

        _connectionController.add(true);

        _resetWatchdog();


      } else {

        if (response.statusCode == 200) {
          debugPrint(
            "UNEXPECTED DATA FROM $host - NOT OUR DEVICE",
          );
        } else {
          debugPrint(
            "HTTP STATUS ${response.statusCode}",
          );
        }

        _setDisconnected();

      }


    } catch (e) {

      debugPrint(
        "HTTP ERROR $e",
      );


      _setDisconnected();


    } finally {

      _httpRequestInFlight = false;

    }

  }



  /// Closes every active transport (WebSocket + HTTP polling + watchdog)
  /// without emitting user facing state. Stale stream callbacks are
  /// cancelled first so an old connection cannot clobber a fresh one.
  Future<void> _closeTransport() async {

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _httpTimer?.cancel();
    _httpTimer = null;
    _httpRequestInFlight = false;
    _usingHttpFallback = false;

    _connectAttemptInProgress = false;

    // Reset silently (no events): callers re-emit state as needed.
    _connected = false;


    final channel = _channel;
    _channel = null;

    await _channelSubscription?.cancel();
    _channelSubscription = null;


    if (channel != null) {

      try {

        // On a dead link the close handshake can hang forever, so cap it
        // and move on; the operating system reclaims the socket.
        await channel.sink.close().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );

      } catch (_) {
        // Socket was already gone.
      }

    }

  }



  void _setDisconnected() {

    _connected = false;

    _connectionController.add(false);

    _statusController.add(DeviceStatus.disconnected());

  }



  /// Called when the operating system reports that every network
  /// interface went down (e.g. the user turned WiFi off). In that state
  /// the WebSocket never receives a close event, so the drop has to be
  /// applied directly instead of waiting for timeouts.
  void handleNetworkLost() {

    debugPrint(
      "NETWORK LOST - MARKING DISCONNECTED",
    );

    unawaited(_closeTransport());

    _setDisconnected();

  }



  /// Called when at least one network interface is back, or when the
  /// device jumps from one network to another (e.g. the phone leaves the
  /// device hotspot and joins home WiFi). A live "connection" cannot be
  /// trusted after such a jump, so it is verified against real device
  /// telemetry before keeping it.
  void handleNetworkAvailable() {

    debugPrint(
      "NETWORK AVAILABLE",
    );


    if (_connected) {
      unawaited(_verifyActiveConnection());
      return;
    }


    if (_connectAttemptInProgress ||
        _usingHttpFallback) {
      return;
    }


    if (!_autoReconnectEnabled) {
      return;
    }


    debugPrint(
      "NETWORK AVAILABLE - RECONNECTING",
    );

    unawaited(reconnect());

  }



  /// Re-checks the link to the device after a network change. The socket
  /// survives roaming silently, so the only reliable proof is whether the
  /// device still answers with valid telemetry.
  Future<void> _verifyActiveConnection() async {

    if (!_connected) {
      return;
    }

    debugPrint(
      "NETWORK CHANGED - VERIFYING DEVICE LINK",
    );

    final alive = await _probeHttp();


    if (alive) {

      debugPrint(
        "DEVICE LINK STILL VALID",
      );

      _resetWatchdog();

      if (_autoReconnectEnabled) {
        _startHttpFallback(_activeHost);
      }

      return;

    }


    debugPrint(
      "DEVICE LINK VERIFICATION FAILED - CONNECTION LOST",
    );


    await _closeTransport();

    _setDisconnected();


    if (_autoReconnectEnabled) {
      _startHttpFallback(_activeHost);
    }

  }



  /// Parses a raw payload into a [DeviceStatus], or returns `null` when
  /// the payload is not valid device telemetry. Used both for updates and
  /// as proof that whatever answered is really the Car Guard device.
  DeviceStatus? _parseStatus(
    String data,
  ) {

    try {

      if (data.trim().startsWith('{')) {

        final json =
            jsonDecode(data);


        return DeviceStatus(

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


      }


      final parts =
          data.split(',');


      if (parts.length < 4) {

        return null;

      }


      return DeviceStatus(

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


    } catch (e) {


      debugPrint(
        "DATA PARSE ERROR : $e",
      );


      debugPrint(
        data,
      );


      return null;

    }

  }



  /// Handles an incoming payload from any transport. Emits the parsed
  /// status and reports whether the payload was valid device telemetry;
  /// invalid data never counts as proof that the device is alive.
  bool _handleData(
    String data,
  ) {

    final status = _parseStatus(data);


    if (status == null) {

      debugPrint(
        "INVALID DEVICE DATA",
      );

      return false;

    }


    _statusController.add(
      status,
    );

    return true;

  }



  @override
  Future<void> disconnect() async {

    _autoReconnectEnabled = false;

    await _closeTransport();

    _setDisconnected();

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

      try {

        _channel!.sink.add(
          jsonEncode(payload),
        );

      } catch (e) {

        debugPrint(
          "WS SEND ERROR $e",
        );

      }


      return;

    }



    try {


      await http
          .post(
            Uri.parse(
              "http://$_activeHost${DeviceEndpoints.dashboard}",
            ),
            headers: const {
              "Content-Type":
                  "application/json",
            },
            body:
                jsonEncode(payload),
          )
          .timeout(_httpTimeout);


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
