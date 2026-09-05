import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/device_endpoints.dart';
import '../models/license_models.dart';
import 'device_models.dart';
import 'device_repository.dart';
import 'mdns_discovery_service.dart';
import 'network_binding_service.dart';

/// Factory used by the repository to create its one WebSocket transport.
///
/// Keeping this injectable makes the transport/watchdog contract testable
/// without changing the production connector or opening a second socket.
typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

class Esp8266Repository implements DeviceRepository {
  Esp8266Repository({
    required this.host,
    this.port = 81,
    this.httpPort = 80,
    this.enableMdnsDiscovery = true,
    this.watchdogTimeout = const Duration(seconds: 6),
    this.httpTimeout = const Duration(seconds: 3),
    this.webSocketInitialTimeout = const Duration(milliseconds: 1500),
    // Keep the activation response window at twelve seconds so the firmware
    // can finish validation and EEPROM persistence without a transport race.
    this.licenseRequestTimeout = const Duration(seconds: 12),
    WebSocketConnector? webSocketConnector,
  }) : _activeHost = host,
       _activePort = port,
       _webSocketConnector = webSocketConnector ?? WebSocketChannel.connect;

  final String host;
  final int port;

  /// HTTP is normally served on port 80 while the telemetry WebSocket uses
  /// port 81. Tests and alternate module builds may expose both transports on
  /// another port without changing the production defaults.
  final int httpPort;

  /// mDNS remains enabled by default; tests can turn discovery off so they
  /// exercise only the WebSocket/watchdog behavior.
  final bool enableMdnsDiscovery;

  /// These defaults are the production transport timings. They are constructor
  /// options so watchdog tests can run faster; the license timeout remains
  /// twelve seconds for the complete firmware activation response.
  final Duration watchdogTimeout;
  final Duration httpTimeout;
  final Duration webSocketInitialTimeout;
  final Duration licenseRequestTimeout;

  final WebSocketConnector _webSocketConnector;

  String _activeHost;
  int _activePort;

  String _httpUrl(String targetHost, String pathAndQuery) {
    final portSuffix = httpPort == 80 ? '' : ':$httpPort';
    return 'http://$targetHost$portSuffix$pathAndQuery';
  }

  /// Returns the phone's current UTC Unix time in seconds. This value is sent
  /// only as the activation/status time input; the signed license payload and
  /// activation code remain byte-for-byte unchanged.
  int _phoneEpochSeconds() {
    return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  WebSocketChannel? _channel;
  Timer? _httpTimer;
  Timer? _wsTimeoutTimer;

  /// Fires when no valid data arrived for [watchdogTimeout] while the link
  /// was believed to be up: a dead TCP connection (WiFi toggled off, module
  /// powered down) never delivers a close frame, so silence is the signal.
  Timer? _watchdogTimer;

  /// Held so a replaced/abandoned socket's callbacks can be cancelled
  /// before they can clobber a newer connection.
  StreamSubscription<dynamic>? _channelSubscription;

  /// Serializes fallback polls: a stuck request must not stack followers.
  bool _httpRequestInFlight = false;

  /// Invalidates an HTTP poll that belongs to an older transport session. A
  /// response from such a poll must not mark a newly-created WebSocket
  /// disconnected (or revive an obsolete fallback loop).
  int _httpFallbackGeneration = 0;

  /// Consecutive failed fallback polls; a single dropped packet must not
  /// flap the UI to Disconnected.
  int _pollFailureCount = 0;

  /// True after at least one valid license-protocol reply has arrived on the
  /// current WebSocket. This is separate from telemetry: a LOCKED module can
  /// keep the license socket alive without sending sensor frames.
  bool _licenseProofOfLife = false;

  /// Whether this WebSocket session has already produced telemetry. Keeping
  /// this bit separate means a known ACTIVE session retains the exact original
  /// telemetry/HTTP watchdog path even while its license handshake is still
  /// settling.
  bool _telemetrySeenOnSocket = false;

  /// Last authorized reading for a newly authorized stream subscriber. This
  /// is cleared on LOCKED/disconnect, so it cannot become a stale leak.
  DeviceStatus? _lastTelemetryStatus;

  /// Monotonic count of valid license replies on the current socket. It lets a
  /// watchdog probe accept any valid license reply that raced with its own
  /// request, not just the exact reply type it asked for.
  int _licenseActivityGeneration = 0;

  /// Latest authoritative status observed during this WebSocket session. A
  /// session with telemetry keeps the normal telemetry/HTTP watchdog behavior;
  /// a license reply is used as a probe only when no sensor frame has arrived.
  LicenseDeviceStatus? _licenseDeviceStatus;

  /// Last status known from the module, retained across the transport handoff
  /// so a LOCKED module cannot become visible merely because its redacted CSV
  /// fallback has no status field. ACTIVE is likewise retained only as the
  /// fallback's authorization context; it never grants protected controls.
  LicenseDeviceStatus? _lastKnownLicenseStatus;

  /// Repeats the last license query that can safely act as a proof-of-life
  /// probe. LICENSE_RESULT is not itself a repeatable request, so it falls
  /// back to LICENSE_STATUS.
  String? _lastLicenseCommand;

  /// Prevents an overlapping watchdog probe from declaring a healthy socket
  /// dead while the previous probe is still awaiting its reply.
  bool _licenseWatchdogProbeInFlight = false;

  /// An explicit license request is also proof that the socket is being used.
  /// Do not let the inactivity timer close the transport at the exact moment
  /// that request is waiting for its first reply (the short test timings make
  /// that race easy to hit, and the production timings can hit it after a
  /// cold Wi-Fi wake-up too).
  int _licenseRequestsInFlight = 0;

  final StreamController<DeviceStatus> _statusController =
      StreamController<DeviceStatus>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  /// License-protocol replies (DEVICE_SERIAL / LICENSE_STATUS / LICENSE_RESULT)
  /// answered by the module over the SAME WebSocket as telemetry — no second
  /// connection is ever opened.
  final StreamController<LicenseMessage> _licenseController =
      StreamController<LicenseMessage>.broadcast();

  /// Completes when the WebSocket channel has been created, so a license query
  /// can wait for the transport before sending even when no sensor frame has
  /// arrived yet.
  Completer<void>? _transportReady;

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
  static const String autoJoinEnabledKey = 'wifi_auto_join';

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

  @override
  Stream<bool> get connectionStream =>
      _connectionController.stream;

  @override
  Stream<LicenseMessage> get licenseStream =>
      _licenseController.stream;


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

    // Mark the moment the transport will be available for license queries;
    // command readiness must not depend on the first sensor reading.
    _transportReady = Completer<void>();

    // Optional direct, app-scoped pairing (paired from Settings -> Device
    // connection): keeps the module reachable while 4G stays the phone's
    // internet route without any system dialog.
    await _maybePairModuleWifi();

    // If the user enabled system-level auto-join, (re)register the Wi-Fi
    // suggestion — idempotent and needed after module Wi-Fi renames.
    await _maybeReapplyWifiAutoJoin();

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
    if (enableMdnsDiscovery &&
        (_lastMdnsLookup == null ||
            DateTime.now().difference(_lastMdnsLookup!) >
                const Duration(minutes: 1))) {
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

      final channel = _webSocketConnector(
        Uri.parse(
          "ws://$host:$wsPort",
        ),
      );
      _channel = channel;

      // From here on the socket can carry text frames, so a license command
      // may be sent even before any telemetry arrives. Capture the channel
      // locally as well: callbacks from an old socket must never affect a
      // newer connection during reconnect/close races.
      final ready = _transportReady;
      if (ready != null && !ready.isCompleted) {
        ready.complete();
      }

      _channelSubscription = channel.stream.listen(

        (message) {

          // A queued callback from a cancelled socket must not feed data into
          // a newer connection or revive a session that is being torn down.
          if (_stopped || !identical(_channel, channel)) {
            return;
          }

          debugPrint(
            "WS DATA = $message",
          );


          // Only genuine device telemetry may keep the connection alive:
          // on a foreign network some other service could answer on the
          // module IP, and its garbage must not fake a live link.
          final valid = _handleData(
            message.toString(),
          );

          if (!valid) {
            return;
          }


          _markConnectionAlive();

        },


        onDone: () {

          debugPrint(
            "WS CLOSED",
          );

          if (_stopped || !identical(_channel, channel)) {
            return;
          }

          // The HTTP fallback owns dead-device detection from here on.
          _watchdogTimer?.cancel();
          _watchdogTimer = null;
          _wsTimeoutTimer?.cancel();
          _wsTimeoutTimer = null;

          // The stream has ended even though the channel object is still
          // reachable. Detach it before HTTP fallback can mark itself alive;
          // otherwise a later license write could hit this closed sink.
          _channel = null;

          _setDisconnected();

          _startHttpFallback(host);

          _scheduleWsReconnect();


        },


        onError: (error) {

          debugPrint(
            "WS ERROR $error",
          );

          if (_stopped || !identical(_channel, channel)) {
            return;
          }

          // The HTTP fallback owns dead-device detection from here on.
          _watchdogTimer?.cancel();
          _watchdogTimer = null;
          _wsTimeoutTimer?.cancel();
          _wsTimeoutTimer = null;

          // The stream has ended even though the channel object is still
          // reachable. Detach it before HTTP fallback can mark itself alive;
          // otherwise a later license write could hit this closed sink.
          _channel = null;

          _setDisconnected();

          _startHttpFallback(host);

          _scheduleWsReconnect();

        },


        cancelOnError: true,

      );


      try {

        if (_stopped || !identical(_channel, channel)) {
          return;
        }

        channel.sink.add(
          "hello",
        );

      } catch (e) {

        // Writing to a freshly-closed socket throws; the onDone/onError
        // handlers take over from here.

        debugPrint(
          "WS HELLO FAILED $e",
        );

      }


      // Data is expected to keep flowing from the module; total silence
      // right after connecting means the link never really came up.
      _resetWatchdog();

      _wsTimeoutTimer?.cancel();

      _wsTimeoutTimer = Timer(
        webSocketInitialTimeout,
        () {

          if (!_connected &&
              !_stopped &&
              identical(_channel, channel)) {

            debugPrint(
              "WS TIMEOUT -> HTTP FALLBACK (1.5s)",
            );

            // A channel object can exist even when the WebSocket handshake
            // never produced a frame. Do not leave that stale channel in
            // place: license commands would otherwise be written to it while
            // /data keeps succeeding over HTTP.
            unawaited(_recoverFromFailedWebSocket(host, channel));

          }

        },
      );


    } catch (e) {

      debugPrint(
        "WS CONNECT FAILED $e",
      );

      await _closeSocket();
      if (_stopped) {
        return;
      }

      _setDisconnected();
      _startHttpFallback(host);
      _scheduleWsReconnect();

    }

  }



  /// Abandons a WebSocket that never produced a valid frame and moves the
  /// repository to the same recovery path used by onDone/onError. Keeping the
  /// failed channel around is especially harmful to activation: HTTP polling
  /// proves that `/data` is reachable, but the license protocol exists only on
  /// a healthy WebSocket.
  Future<void> _recoverFromFailedWebSocket(
    String host,
    WebSocketChannel expectedChannel,
  ) async {
    if (_stopped ||
        _connected ||
        !identical(_channel, expectedChannel)) {
      return;
    }

    await _closeSocket();
    if (_stopped || _channel != null) {
      return;
    }

    _setDisconnected();
    _startHttpFallback(host);
    _scheduleWsReconnect();
  }

  void _startHttpFallback(
    String host,
  ) {

    if (_stopped || _usingHttpFallback) {
      return;
    }


    debugPrint(
      "START HTTP FALLBACK (fast)",
    );


    _usingHttpFallback = true;
    final fallbackGeneration = ++_httpFallbackGeneration;


    _httpTimer?.cancel();

    // محاولة فورية بدون انتظار ثانية، ثم كل 800ms لإعادة الاتصال أسرع
    // لما الموبايل لسه على شبكة الجهاز
    Future<void> doPoll() async {
      // A stuck request must not stack followers on top of each other.
      if (_stopped ||
          !_usingHttpFallback ||
          fallbackGeneration != _httpFallbackGeneration ||
          _httpRequestInFlight) {
        return;
      }

      _httpRequestInFlight = true;

      try {
        final response = await http
            .get(
              Uri.parse(_httpUrl(host, '/data')),
            )
            .timeout(httpTimeout);

        // A bare 200 is not proof of life on a foreign network (a router
        // page or captive portal can answer on the module IP): the body
        // must parse as real device telemetry. Also discard a late response
        // from an obsolete fallback loop.
        if (fallbackGeneration != _httpFallbackGeneration ||
            _stopped ||
            !_usingHttpFallback) {
          return;
        }

        if (response.statusCode == 200 &&
            _handleData(response.body)) {
          // نجاح فوري -> الغي مؤقت الـ WS وأعد الاتصال
          _wsTimeoutTimer?.cancel();
          _wsReconnectTimer?.cancel();
          _wsReconnectAttempts = 0;
          _pollFailureCount = 0;

          // Keep the original fallback ownership semantics: a successful
          // HTTP poll leaves _usingHttpFallback true so the polling loop
          // continues to provide readings until the WebSocket upgrades it.
          _connected = true;
          _connectionController.add(true);
          _resetWatchdog();
        } else {
          _registerPollFailure();
        }
      } catch (e) {
        // الخطأ لا يقطع الـ polling — سيُعاد في الدورة التالية
        _registerPollFailure();
      } finally {
        if (fallbackGeneration == _httpFallbackGeneration) {
          _httpRequestInFlight = false;
        }
      }
    }

    // أول محاولة فورية
    unawaited(doPoll());

    _httpTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => doPoll(),
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


    // تسريع: 1s, 1.5s, 2s, 3s, 5s بدل 3,6,9,12,15
    final delays = [1, 1, 2, 3, 5];
    final idx = (_wsReconnectAttempts - 1).clamp(0, delays.length - 1);
    final delaySeconds = delays[idx];
    final recoveryGeneration = _httpFallbackGeneration;

    debugPrint(
      "WS RECONNECT IN ${delaySeconds}s (attempt $_wsReconnectAttempts/$_maxWsReconnectAttempts)",
    );


    _wsReconnectTimer = Timer(
      Duration(milliseconds: (delaySeconds * 1000).toInt()),
      () {

        _wsReconnectTimer = null;

        if (_stopped ||
            _connected ||
            recoveryGeneration != _httpFallbackGeneration) {
          return;
        }

        // عند إعادة المحاولة بسرعة، لا ننتظر mDNS دقيقة كاملة
        // نسمح باكتشاف جديد إذا فات 10 ثواني فقط
        if (_lastMdnsLookup != null &&
            DateTime.now().difference(_lastMdnsLookup!) >
                const Duration(seconds: 10)) {
          _lastMdnsLookup = null;
        }

        connect(
          host: _activeHost,
          port: _activePort,
        );

      },
    );

  }



  /// Records a valid frame as connection activity. The caller has already
  /// validated that the frame is either telemetry or a license-protocol reply;
  /// both are proof that the existing WebSocket is usable.
  void _markConnectionAlive() {

    _connected = true;
    // The initial-handshake timer is only for a socket that never produces a
    // valid frame. Once status or telemetry arrives it must not wake later
    // after an ordinary close and tear down the HTTP fallback underneath it.
    _wsTimeoutTimer?.cancel();
    _wsTimeoutTimer = null;
    _usingHttpFallback = false;
    _pollFailureCount = 0;

    if (_wsReconnectAttempts != 0) {
      _wsReconnectAttempts = 0;
    }

    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;

    _connectionController.add(true);

    _resetWatchdog();

  }



  void _setDisconnected() {
    _connected = false;
    // A transport transition ends the current authorization session too.
    // Never let a proof from the old socket authorize fallback or a later
    // command after disconnect.
    _clearLicenseConnectionHealth();

    _connectionController.add(false);

    _statusController.add(DeviceStatus.disconnected());

  }



  /// Two consecutive failed polls mean the link is really gone; a single
  /// dropped packet must not flap the UI to Disconnected.
  void _registerPollFailure() {

    _pollFailureCount++;

    if (_pollFailureCount >= 2) {
      _setDisconnected();
    }

  }



  /// Restarts the inactivity watchdog. Called on every piece of data that
  /// actually arrives from the module, no matter which transport served it.
  void _resetWatchdog() {

    _watchdogTimer?.cancel();

    _watchdogTimer = Timer(
      watchdogTimeout,
      _onWatchdogTimeout,
    );

  }



  /// No data arrived for [watchdogTimeout] while the link was believed to
  /// be up. A dropped network does not close the socket, so probe the module
  /// once before declaring the connection lost.
  ///
  /// If no sensor frame has arrived yet but a serial/result reply proved the
  /// socket, repeat a license query on that same socket. A LOCKED status is a
  /// terminal proof for a telemetry-silent device and is kept stable without
  /// sending the same status command over and over. A stalled active/unknown
  /// session still follows the existing close/fallback/reconnect path.
  Future<void> _onWatchdogTimeout() async {

    if (_stopped) {
      return;
    }

    // A caller may have just started DEVICE_SERIAL, LICENSE_STATUS, or
    // LICENSE_ACTIVATE. Waiting for that authoritative reply is safer than
    // treating the still-silent socket as dead and replacing it underneath
    // the request.
    if (_licenseRequestsInFlight > 0) {
      _resetWatchdog();
      return;
    }

    // LOCKED modules intentionally have no telemetry. Once the module has
    // answered LICENSE_STATUS with LOCKED, repeatedly sending the same probe
    // would turn a valid proof-of-life into a reconnect storm (and would
    // write to a sink that may be closing). Keep the established WebSocket
    // session; an actual close/error or a later explicit license action still
    // drives recovery.
    if (_licenseDeviceStatus == LicenseDeviceStatus.locked &&
        !_telemetrySeenOnSocket) {
      _resetWatchdog();
      return;
    }

    final socketAtTimeout = _channel;

    try {

      debugPrint(
        "WATCHDOG TIMEOUT - PROBING MODULE",
      );

      final licenseSession =
          _licenseProofOfLife &&
          !_telemetrySeenOnSocket &&
          _licenseDeviceStatus != LicenseDeviceStatus.active &&
          socketAtTimeout != null;

      if (licenseSession) {
        if (_licenseWatchdogProbeInFlight) {
          // The in-flight probe owns the health decision. Do not let a
          // duplicate timer race it into a false reconnect.
          _resetWatchdog();
          return;
        }

        debugPrint(
          "WATCHDOG TIMEOUT - PROBING LICENSE OVER WEBSOCKET",
        );

        final alive = await _probeLicenseOverWebSocket(socketAtTimeout);

        // A network transition or explicit disconnect may have replaced the
        // socket while the asynchronous probe was waiting for its reply.
        if (_stopped || _channel != socketAtTimeout) {
          return;
        }

        if (alive) {
          debugPrint(
            "MODULE STILL ALIVE VIA LICENSE WEBSOCKET",
          );

          // The response is handled by the normal WebSocket listener, which
          // marks the connection alive and resets the watchdog. Keep this
          // guard for unusual channel implementations that complete the
          // request before the listener callback returns.
          if (_watchdogTimer == null) {
            _resetWatchdog();
          }

          return;
        }
      } else {
        // ACTIVE devices deliberately retain the original telemetry/HTTP
        // watchdog behavior. License state never changes their fallback path.
        final alive = await _probeHttp();

        if (_stopped || _channel != socketAtTimeout) {
          return;
        }

        if (alive) {

          // The module still answers over HTTP but the WebSocket went quiet:
          // keep receiving through the fallback without dropping the session.
          debugPrint(
            "MODULE STILL ALIVE VIA HTTP - USING FALLBACK",
          );

          _resetWatchdog();

          _startHttpFallback(_activeHost);

          return;

        }
      }


      debugPrint(
        "MODULE NOT RESPONDING - CONNECTION LOST",
      );


      await _closeSocket();

      // Another recovery path may have installed a new channel while the
      // close handshake was awaiting completion. Its lifecycle now owns the
      // repository; do not let this stale watchdog callback tear it down.
      if (_stopped || _channel != null) {
        return;
      }

      _setDisconnected();

      _startHttpFallback(_activeHost);

      // Keep trying the WebSocket too: once the module is back the live
      // stream upgrades back from HTTP polling.
      _scheduleWsReconnect();


    } catch (e) {

      debugPrint(
        "WATCHDOG ERROR $e",
      );

    }

  }



  /// Checks a license-proven WebSocket without creating another socket. The
  /// last repeatable handshake request is used for serial-only sessions;
  /// LICENSE_RESULT replies are followed by a LICENSE_STATUS probe.
  Future<bool> _probeLicenseOverWebSocket(
    WebSocketChannel socket,
  ) async {

    if (_stopped || _channel != socket || _licenseWatchdogProbeInFlight) {
      return false;
    }

    _licenseWatchdogProbeInFlight = true;
    final activityBeforeProbe = _licenseActivityGeneration;

    try {
      final response = _lastLicenseCommand == 'DEVICE_SERIAL'
          ? await getDeviceSerial()
          : await getLicenseStatus();

      if (_stopped || _channel != socket) {
        return false;
      }

      // The normal listener marks every valid license response as activity.
      // Accept a response that raced with this probe even when it was a
      // different license message type (for example LICENSE_RESULT).
      final receivedLicenseActivity =
          response != null ||
          _licenseActivityGeneration != activityBeforeProbe;
      if (!receivedLicenseActivity) {
        return false;
      }

      // The WebSocket listener has already called _markConnectionAlive for
      // this response. This explicit reset documents and guarantees the
      // proof-of-life contract even if a channel delivers the request future
      // before the listener's final callback work.
      _resetWatchdog();
      return true;
    } finally {
      _licenseWatchdogProbeInFlight = false;
    }

  }



  /// Single quick HTTP probe used by the watchdog and the network-change
  /// verification to confirm whether the module is truly reachable. Only a
  /// body that parses as real telemetry counts as alive.
  Future<bool> _probeHttp() async {

    try {

      final response = await http
          .get(
            Uri.parse(_httpUrl(_activeHost, '/data')),
          )
          .timeout(httpTimeout);

      return response.statusCode == 200 &&
          _parseStatus(response.body) != null;

    } catch (_) {

      return false;

    }

  }



  /// Drops the current transport without flagging the session as stopped
  /// (unlike [disconnect], which is an intentional user action): recovery
  /// paths stay allowed to bring the link back automatically.
  Future<void> _closeSocket() async {

    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _wsTimeoutTimer?.cancel();
    _wsTimeoutTimer = null;

    // Invalidate any in-flight fallback request before replacing the socket.
    _httpFallbackGeneration++;
    _httpTimer?.cancel();
    _httpTimer = null;
    _httpRequestInFlight = false;
    _usingHttpFallback = false;
    _pollFailureCount = 0;

    _connected = false;
    _clearLicenseConnectionHealth();

    // Release any license query waiting for the transport to come up.
    final ready = _transportReady;
    if (ready != null && !ready.isCompleted) {
      ready.complete();
    }
    _transportReady = null;

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



  /// Called when the operating system reports that every network interface
  /// went down (e.g. the user turned WiFi off). The socket is never told in
  /// that case, so the drop is applied directly instead of waiting for
  /// timeouts. The session is NOT stopped: recovery resumes automatically
  /// from [handleNetworkAvailable].
  void handleNetworkLost() {

    debugPrint(
      "NETWORK LOST - MARKING DISCONNECTED",
    );


    // Retrying while every interface is down is pointless.
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _wsReconnectAttempts = 0;

    _wsTimeoutTimer?.cancel();
    _wsTimeoutTimer = null;


    unawaited(_closeSocket());

    _setDisconnected();

  }



  /// Called when at least one network interface is back, or when the phone
  /// jumps between networks (e.g. leaves the module hotspot and joins home
  /// WiFi). A live "connection" cannot be trusted after such a jump, so it
  /// is verified against real device telemetry before being kept.
  void handleNetworkAvailable() {

    debugPrint(
      "NETWORK AVAILABLE",
    );


    if (_connected) {
      unawaited(_verifyActiveConnection());
      return;
    }


    if (_stopped ||
        _usingHttpFallback ||
        _wsReconnectTimer != null) {
      // Either the user disconnected on purpose, or a recovery path is
      // already polling/retrying and will restore the link by itself.
      return;
    }


    debugPrint(
      "NETWORK AVAILABLE - RECONNECTING",
    );

    unawaited(
      connect(
        host: _activeHost,
        port: _activePort,
      ),
    );

  }



  /// Re-checks the link to the module after a network change. The socket
  /// survives roaming silently, so the only reliable proof is whether the
  /// module still answers with valid telemetry.
  Future<void> _verifyActiveConnection() async {

    if (!_connected || _stopped) {
      return;
    }

    debugPrint(
      "NETWORK CHANGED - VERIFYING MODULE LINK",
    );

    final alive = await _probeHttp();


    if (alive) {

      debugPrint(
        "MODULE LINK STILL VALID",
      );

      _resetWatchdog();

      _startHttpFallback(_activeHost);

      return;

    }


    debugPrint(
      "MODULE LINK VERIFICATION FAILED - CONNECTION LOST",
    );


    await _closeSocket();

    _setDisconnected();

    _startHttpFallback(_activeHost);

    _scheduleWsReconnect();

  }



  /// True only after a fresh ACTIVE license reply on this WebSocket session.
  /// A cached Flutter state is never consulted here.
  @override
  bool get hasAuthoritativeActiveLicense =>
      _licenseProofOfLife &&
      _licenseDeviceStatus == LicenseDeviceStatus.active;

  /// Returns whether a write/control endpoint may be used. Keeping this check
  /// inside the transport prevents a protected control from being bypassed by
  /// merely hiding its button in the UI.
  bool _protectedCommandAllowed(String operation) {
    if (hasAuthoritativeActiveLicense) return true;

    debugPrint('PROTECTED COMMAND BLOCKED (license not ACTIVE): $operation');
    return false;
  }

  /// Sends a raw GET command to the connected module and reports whether it
  /// acknowledged the request.
  Future<bool> sendDeviceCommand(String endpoint) async {

    if (!_protectedCommandAllowed(endpoint) || _stopped) {
      return false;
    }


    try {

      final response = await http
          .get(
            Uri.parse(_httpUrl(_activeHost, endpoint)),
          )
          .timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 423) {
        // The firmware uses 423 LOCKED for protected controls while the
        // telemetry endpoint remains readable. Never treat that response as
        // a transport failure or as a successful command.
        debugPrint(
          'DEVICE COMMAND LOCKED (423) $endpoint: ${response.body}',
        );
        return false;
      }

      if (response.statusCode != 200) {
        debugPrint(
          'DEVICE COMMAND REJECTED (${response.statusCode}) $endpoint: '
          '${response.body}',
        );
        return false;
      }

      return true;

    } catch (e) {

      debugPrint(
        "DEVICE COMMAND FAILED $endpoint : $e",
      );

      return false;

    }

  }



  /// Reads one fresh telemetry frame after a fan command.
  ///
  /// The module's WebSocket broadcaster skips frames when temperature and
  /// voltage are unchanged, so a fan-only state transition may otherwise not
  /// reach the live status stream. This uses the existing `/data` telemetry
  /// endpoint and [DeviceStatus.controlData.fanRunning] remains authoritative;
  /// no local fan state is created.
  Future<void> _refreshLiveStatus() async {
    if (_stopped) return;

    try {
      final response = await http
          .get(Uri.parse(_httpUrl(_activeHost, '/data')))
          .timeout(httpTimeout);

      if (response.statusCode == 200) {
        _handleData(response.body);
      }
    } catch (e) {
      debugPrint('LIVE STATUS REFRESH FAILED: $e');
    }
  }

  Future<bool> _sendFanCommand(String endpoint) async {
    final succeeded = await sendDeviceCommand(endpoint);
    if (succeeded) {
      await _refreshLiveStatus();
    }
    return succeeded;
  }

  /// Silences the module buzzer (`/mute`).
  Future<bool> muteBuzzer() => sendDeviceCommand(DeviceEndpoints.mute);

  /// Runs the radiator fan test (`/testfan`).
  Future<bool> testFan() => sendDeviceCommand(DeviceEndpoints.testFan);

  /// Enables the firmware's persistent manual radiator-fan override (`/fanon`).
  Future<bool> fanOn() => _sendFanCommand(DeviceEndpoints.fanOn);

  /// Cancels the manual radiator-fan override and turns it off (`/fanoff`).
  Future<bool> fanOff() => _sendFanCommand(DeviceEndpoints.fanOff);

  /// Reboots the module (`/restart`).
  Future<bool> restartDevice() => sendDeviceCommand(DeviceEndpoints.restart);


  /// Fetches the settings stored on the module (`/getallsettings`).
  ///
  /// Returns null when the device is unreachable or replies with an
  /// unexpected payload.
  Future<DeviceModuleSettings?> getDeviceSettings() async {
    // Module-limit metadata remains available for the settings UI; the live
    // temperature/voltage output is gated separately by the license status.
    // Save/calibration/control methods below still use _protectedCommandAllowed().
    if (_stopped) {
      return null;
    }

    try {

      final response = await http
          .get(
            Uri.parse(
              _httpUrl(_activeHost, DeviceEndpoints.getAllSettings),
            ),
          )
          .timeout(
            const Duration(seconds: 5),
          );


      if (response.statusCode != 200) {
        debugPrint(
          'DEVICE READ REJECTED (${response.statusCode}): ${response.body}',
        );
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

    if (!_protectedCommandAllowed(DeviceEndpoints.otaUpdate)) {
      return false;
    }

    try {

      final uri = Uri.parse(
        _httpUrl(_activeHost, DeviceEndpoints.otaUpdate),
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
    if (_stopped ||
        !_protectedCommandAllowed(DeviceEndpoints.getWifiSettings)) {
      return null;
    }

    try {

      final response = await http
          .get(
            Uri.parse(
              _httpUrl(_activeHost, DeviceEndpoints.getWifiSettings),
            ),
          )
          .timeout(
            const Duration(seconds: 5),
          );


      if (response.statusCode != 200) {
        debugPrint(
          'DEVICE READ REJECTED (${response.statusCode}): ${response.body}',
        );
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

    if (!_protectedCommandAllowed(DeviceEndpoints.calibrateVoltage)) {
      return null;
    }

    try {

      final response = await http
          .get(
            Uri.parse(
              '${_httpUrl(_activeHost, DeviceEndpoints.calibrateVoltage)}?realVolt=$realVolt',
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
  /// يرسل كل من `password` و `pass` لضمان التوافق مع كل نسخ الفيرموير.
  Future<bool> saveWifiSettings({
    required String ssid,
    required String password,
  }) async {
    // إرسال الاثنين معاً لتوافق الفيرموير القديم (pass) والجديد (password)
    final encodedSsid = Uri.encodeComponent(ssid);
    final encodedPass = Uri.encodeComponent(password);
    return _getExpectsOk(
      "${DeviceEndpoints.saveWifiSettings}"
      "?ssid=$encodedSsid"
      "&password=$encodedPass"
      "&pass=$encodedPass",
    );
  }

  /// [STA+mDNS] Tells the module to join another network (phone hotspot or
  /// home router) in addition to its own AP (`/joinwifi`). The credentials
  /// persist on the module, so it re-joins by itself after every boot and
  /// mDNS lets the app find it back automatically.
  /// يرسل `pass` و `password` معاً + يحاول بدائل الفيرموير المختلفة.
  Future<bool> joinExternalWifi({
    required String ssid,
    required String password,
  }) async {
    final encodedSsid = Uri.encodeComponent(ssid);
    final encodedPass = Uri.encodeComponent(password);

    // جرّب أولاً بصيغة pass (الأصلية)، لو فشل جرّب password
    // بعض نسخ النود تستخدم pass والبعض password
    var ok = await _getExpectsOk(
      "${DeviceEndpoints.joinWifi}"
      "?ssid=$encodedSsid"
      "&pass=$encodedPass"
      "&password=$encodedPass",
    );
    if (ok) return true;

    // محاولة بديلة: بعض الفيرموير يستخدم /savewifi حتى للـ STA
    debugPrint("JOINWIFI RETRY via /savewifi");
    return _getExpectsOk(
      "${DeviceEndpoints.saveWifiSettings}"
      "?ssid=$encodedSsid"
      "&password=$encodedPass"
      "&pass=$encodedPass",
    );
  }



  /// Wipes everything stored on the module EEPROM (`/factoryreset`) and
  /// reboots it into factory defaults: AP name CarGaurd / 12345678, default
  /// limits, empty STA creds.
  Future<bool> factoryResetModule() => _getExpectsOk(DeviceEndpoints.factoryReset);



  Future<bool> _getExpectsOk(String pathAndQuery) async {
    if (_stopped || !_protectedCommandAllowed(pathAndQuery)) {
      return false;
    }

    try {

      final response = await http
          .get(
            Uri.parse(_httpUrl(_activeHost, pathAndQuery)),
          )
          .timeout(
            const Duration(seconds: 8),
          );

      final body = response.body.trim();
      if (response.statusCode == 423) {
        debugPrint(
          'DEVICE REQUEST LOCKED (423) $pathAndQuery: $body',
        );
        return false;
      }

      if (response.statusCode != 200) {
        debugPrint(
          'DEVICE REQUEST REJECTED (${response.statusCode}) '
          '$pathAndQuery: $body',
        );
        return false;
      }

      if (body.toUpperCase() != "OK") {
        debugPrint(
          'DEVICE REQUEST UNEXPECTED RESPONSE $pathAndQuery: $body',
        );
        return false;
      }

      return true;

    } catch (e) {

      debugPrint(
        "DEVICE REQUEST FAILED $pathAndQuery : $e",
      );

      return false;

    }

  }




  /// Parses a raw payload into a [DeviceStatus], or returns `null` when
  /// the payload is not valid device telemetry. Used both for live updates
  /// and as proof that whatever answered is really the Car Guard module.
  DeviceStatus? _parseStatus(
    String data,
  ) {

    _ensureModuleLimitsLoaded();

    try {

      if (data.trim().startsWith('{')) {

        final json =
            jsonDecode(data);

        // Current firmware keeps /data available for license diagnostics but
        // marks locked/expired responses explicitly. Never reinterpret the
        // redacted zero placeholders as a live reading.
        final licenseStatus = json["licenseStatus"];
        if (licenseStatus is String && licenseStatus != 'ACTIVE') {
          return null;
        }

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
          return null;
        }


        // A payload that cannot even produce the two core numbers is noise
        // from a foreign service (router page, captive portal...), not
        // module telemetry.
        final tempCelsius = double.tryParse(parts[0].trim());
        final volt = double.tryParse(parts[1].trim());

        if (tempCelsius == null || volt == null) {

          debugPrint(
            "INVALID DEVICE DATA",
          );

          return null;

        }


        // Reference protocol (from the original Kayan dashboard):
        // temp,volt,fanState,?,maxTemp,fanOnTemp,minVolt,maxVolt,offset
        return DeviceStatus(

          connected: true,

          deviceId: "Car Guard",


          batteryData: BatteryData(

            voltage: volt,

          ),


          temperatureData:
              TemperatureData(

            engineTemperature: tempCelsius,

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



  /// Remembers the license proof carried by a valid response. A known ACTIVE
  /// status deliberately leaves the original telemetry watchdog in charge;
  /// A session without telemetry can use its existing license exchange as the
  /// watchdog probe instead.
  void _recordLicenseActivity(LicenseMessage message) {

    _licenseProofOfLife = true;
    _licenseActivityGeneration++;

    if (message is LicenseStatusMessage) {
      _licenseDeviceStatus = message.status;
      _lastKnownLicenseStatus = message.status;
    }

  }



  void _invalidateLicenseAuthorization() {
    _licenseProofOfLife = false;
    _licenseDeviceStatus = null;
    _lastTelemetryStatus = null;
    _statusController.add(DeviceStatus.disconnected());
  }

  void _clearLicenseConnectionHealth() {

    if (_licenseDeviceStatus != null) {
      _lastKnownLicenseStatus = _licenseDeviceStatus;
    }

    _licenseProofOfLife = false;
    _telemetrySeenOnSocket = false;
    _lastTelemetryStatus = null;
    _licenseActivityGeneration = 0;
    _licenseDeviceStatus = null;
    _lastLicenseCommand = null;
    _licenseWatchdogProbeInFlight = false;

  }



  /// Handles an incoming payload from any transport: parses valid telemetry
  /// and reports whether parsing succeeded. Locked/expired firmware responses
  /// are redacted and never enter the live-reading stream. Invalid data never
  /// counts as proof that the module is alive.
  ///
  /// License-protocol replies ride the same channel and are routed to
  /// [licenseStream] instead of telemetry. A valid license reply is also proof
  /// of life for sessions that have not produced a sensor frame yet.
  bool _handleData(
    String data,
  ) {

    final license = parseLicenseMessage(data);

    if (license != null) {

      _recordLicenseActivity(license);

      if (license is LicenseStatusMessage &&
          license.status != LicenseDeviceStatus.active) {
        // Clear the last real sample as soon as the module reports LOCKED or
        // EXPIRED (firmware represents both as LOCKED). License replies still
        // remain available on this same WebSocket.
        _telemetrySeenOnSocket = false;
        _lastTelemetryStatus = null;
        _statusController.add(DeviceStatus.disconnected());
      }

      if (!_licenseController.isClosed) {
        _licenseController.add(license);
      }

      return true;

    }

    // Once the module has explicitly reported LOCKED, do not promote any
    // sensor frame from that session. An ACTIVE JSON /data response remains
    // usable during the existing HTTP fallback path; the UI provider still
    // requires a fresh ACTIVE license proof before exposing that stream.

    final status = _parseStatus(data);


    if (status == null) {

      debugPrint(
        "INVALID DEVICE DATA",
      );

      return false;

    }

    final telemetryIsLocked =
        _licenseDeviceStatus == LicenseDeviceStatus.locked ||
        (_licenseDeviceStatus == null &&
            _lastKnownLicenseStatus == LicenseDeviceStatus.locked);
    if (telemetryIsLocked) {
      debugPrint("TELEMETRY BLOCKED — LICENSE_REQUIRED");
      return false;
    }


    _telemetrySeenOnSocket = true;
    if (_licenseDeviceStatus == LicenseDeviceStatus.active) {
      _lastTelemetryStatus = status;
    }
    _statusController.add(status);

    return true;

  }




  @override
  Future<void> disconnect() async {

    // Flag first so the WebSocket onDone/onError callbacks triggered by
    // closing the sink below cannot restart the HTTP fallback timer.
    _stopped = true;

    // Release the Wi-Fi binding so the app follows the system network again.
    unawaited(NetworkBindingService.bindToDefault());

    _watchdogTimer?.cancel();

    _watchdogTimer = null;

    // Any response from the previous fallback request is stale once an
    // explicit disconnect starts.
    _httpFallbackGeneration++;

    await _channelSubscription?.cancel();

    _channelSubscription = null;

    _httpTimer?.cancel();

    _httpTimer = null;

    _wsTimeoutTimer?.cancel();

    _wsTimeoutTimer = null;

    _wsReconnectTimer?.cancel();

    _wsReconnectTimer = null;

    _wsReconnectAttempts = 0;

    try {
      await _channel?.sink.close().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } catch (_) {
      // The socket may already be gone.
    }


    _channel = null;

    // Release any license query waiting for the transport to come up.
    final ready = _transportReady;
    if (ready != null && !ready.isCompleted) {
      ready.complete();
    }
    _transportReady = null;


    _connected = false;
    _clearLicenseConnectionHealth();

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
    final command = payload['cmd'];
    final isLicenseCommand = command == 'DEVICE_SERIAL' ||
        command == 'LICENSE_STATUS' ||
        command == 'LICENSE_ACTIVATE';

    if (isLicenseCommand) {
      // License traffic is deliberately WebSocket-only. It must never fall
      // through to the generic HTTP telemetry endpoint, and it is the one
      // unauthenticated command family needed to establish authorization.
      final channel = _channel;
      if (_stopped || channel == null) {
        throw StateError('No WebSocket transport for license command');
      }

      // Capture the channel before writing. A close/reconnect can replace the
      // repository field between the health check and sink.add; never write
      // through a stale field, and let the request layer turn a closed sink
      // into a normal failed probe instead of an unhandled async error.
      if (!identical(_channel, channel)) {
        throw StateError('WebSocket transport was replaced');
      }
      channel.sink.add(jsonEncode(payload));
      return;
    }

    // Any other raw JSON write is a protected control. Public callers cannot
    // bypass the endpoint-specific guards by using this lower-level method.
    if (!_protectedCommandAllowed('raw JSON') || _stopped) return;

    try {
      final channel = _channel;
      if (channel != null && identical(_channel, channel)) {
        channel.sink.add(jsonEncode(payload));
        return;
      }

      await http.post(
        Uri.parse(_httpUrl(_activeHost, '/data')),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint("HTTP SEND ERROR $e");
    }
  }




  @override
  Stream<DeviceStatus> get liveUpdates {
    // Replay only the last authorized frame to a new subscriber. The cache is
    // cleared whenever the license/transport becomes invalid, so activation
    // can resume immediately without retaining locked readings.
    late StreamController<DeviceStatus> replayController;
    StreamSubscription<DeviceStatus>? subscription;
    replayController = StreamController<DeviceStatus>(
      sync: true,
      onListen: () {
        subscription = _statusController.stream.listen(
          replayController.add,
          onError: (Object error, StackTrace stack) {
            replayController.addError(error, stack);
          },
          onDone: replayController.close,
        );
        final cached = _lastTelemetryStatus;
        if (cached != null) replayController.add(cached);
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return replayController.stream;
  }



  @override
  Future<void> reconnect() async {

    await connect(
      host: _activeHost,
      port: _activePort,
    );

  }

  // ------------------------------------------------------------------
  // License protocol (same WebSocket as telemetry — no second connection).
  // ------------------------------------------------------------------

  /// Waits (up to [timeout]) until the WebSocket channel exists so the license
  /// command can be sent over the socket rather than the HTTP fallback (the
  /// module only answers license commands on the WebSocket).
  Future<void> _waitForTransport({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final ready = _transportReady;
    if (ready == null) return;

    // If the channel already exists the completer is (or will be) completed.
    await ready.future.timeout(timeout, onTimeout: () {});
  }

  /// Ensures a license request never uses the stale channel left behind when
  /// HTTP fallback is already serving telemetry. The firmware exposes license
  /// commands only on WebSocket, so a healthy `/data` response is not enough.
  Future<void> _ensureLicenseTransport() async {
    if (_channel != null && !_usingHttpFallback && !_stopped) {
      return;
    }

    // The initial WebSocket may legitimately have no telemetry yet (a LOCKED
    // module can answer the license command first). The stale-channel case is
    // handled by _recoverFromFailedWebSocket(), which switches the repository
    // into HTTP fallback before this method is called.

    // The reconnect timer may be waiting, but an explicit license action
    // should not make the user wait for its backoff. Cancel that timer and
    // establish a fresh WebSocket now.
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;

    if (_channel != null || _usingHttpFallback) {
      await _closeSocket();
    }

    if (_stopped || _channel == null) {
      await connect(host: _activeHost, port: _activePort);
    }

    await _waitForTransport();
  }

  /// Sends a license command and resolves the first matching reply of type
  /// [T], or null on timeout / transport failure.
  Future<T?> _requestLicense<T extends LicenseMessage>(
    Map<String, dynamic> payload,
    bool Function(T) matcher, {
    Duration? timeout,
  }) async {
    final command = payload['cmd'];
    if (command is String) {
      _lastLicenseCommand = command;
    }

    _licenseRequestsInFlight++;
    final completer = Completer<T?>();
    late final StreamSubscription<LicenseMessage> sub;

    sub = _licenseController.stream.listen((message) {
      if (message is T && matcher(message)) {
        if (!completer.isCompleted) completer.complete(message);
      }
    });

    try {
      await _waitForTransport();
      await _ensureLicenseTransport();
      if (_channel == null || _stopped || _usingHttpFallback) {
        debugPrint("LICENSE REQUEST SKIPPED — no healthy WebSocket transport");
        return null;
      }

      await sendJson(payload);
      return await completer.future.timeout(
        timeout ?? licenseRequestTimeout,
        onTimeout: () => null,
      );
    } catch (_) {
      // Socket already gone — treat as no answer rather than surfacing a
      // transport exception to the license UI.
      return null;
    } finally {
      await sub.cancel();
      if (_licenseRequestsInFlight > 0) {
        _licenseRequestsInFlight--;
      }
    }
  }

  /// { "cmd":"DEVICE_SERIAL" } -> { "type":"DEVICE_SERIAL", ... }.
  @override
  Future<DeviceSerialMessage?> getDeviceSerial() =>
      _requestLicense<DeviceSerialMessage>(
        {'cmd': 'DEVICE_SERIAL'},
        (_) => true,
      );

  /// { "cmd":"LICENSE_STATUS","currentTime":<UTC epoch> } ->
  /// { "type":"LICENSE_STATUS", ... }.
  @override
  Future<LicenseStatusMessage?> getLicenseStatus() async {
    final status = await _requestLicense<LicenseStatusMessage>(
      {
        'cmd': 'LICENSE_STATUS',
        'currentTime': _phoneEpochSeconds(),
      },
      (_) => true,
    );

    // A failed authoritative status query must not leave an earlier ACTIVE
    // proof authorizing protected commands or fallback consumers.
    if (status == null) {
      _invalidateLicenseAuthorization();
    }

    return status;
  }

  /// { "cmd":"LICENSE_ACTIVATE","code":...,"activationTime":<UTC epoch> }
  /// -> { "type":"LICENSE_RESULT", ... }.
  @override
  Future<LicenseResultMessage?> activateLicense(String code) =>
      _requestLicense<LicenseResultMessage>(
        {
          'cmd': 'LICENSE_ACTIVATE',
          'code': code,
          'activationTime': _phoneEpochSeconds(),
        },
        (_) => true,
      );


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

  /// If the user enabled system-level auto-join in Settings, (re)registers
  /// the module network as a Wi-Fi suggestion (idempotent) so Android joins
  /// it automatically whenever the module AP is in range — like any saved
  /// network. Uses the same stored credentials as the direct pairing.
  Future<void> _maybeReapplyWifiAutoJoin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (prefs.getString(autoJoinEnabledKey) != 'true') return;

      final ssid = prefs.getString(pairingSsidKey) ?? '';
      final password = prefs.getString(pairingPassKey) ?? '';
      if (ssid.isEmpty) return;

      debugPrint('WIFI AUTO-JOIN REAPPLY -> $ssid');

      await NetworkBindingService.suggestModuleWifi(
        ssid: ssid,
        password: password,
      );
    } catch (e) {
      debugPrint('WIFI AUTO-JOIN REAPPLY FAILED: $e');
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
