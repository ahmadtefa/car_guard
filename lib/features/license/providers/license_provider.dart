import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/license_models.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/services/device_repository.dart';
import '../models/license_state.dart';

/// License state provider.
///
/// The ESP8266 module is the authoritative license authority. This notifier
/// never trusts cached Flutter state: on every new connection it re-queries
/// `DEVICE_SERIAL` then `LICENSE_STATUS` over the existing WebSocket, and it
/// removes real-data authorization whenever that link drops.
final licenseProvider = NotifierProvider<LicenseNotifier, LicenseState>(
  LicenseNotifier.new,
);

/// Narrow dependency used by protected-control gates. It changes only when the
/// authoritative ACTIVE proof changes, so a periodic status refresh does not
/// rebuild read-only telemetry consumers unnecessarily.
final licenseAuthorizationProvider = Provider<bool>((ref) {
  return ref.watch(
    licenseProvider.select((state) => state.canUseProtectedControls),
  );
});

class LicenseNotifier extends Notifier<LicenseState> {
  DeviceRepository _repo = _emptyRepo();
  bool _refreshing = false;
  bool _connectionKnownUp = false;

  /// Retried queries: a LOCKED module broadcasts no telemetry, so the socket
  /// channel may be open before any genuine data proves the link is live. We
  /// still need to send `DEVICE_SERIAL` as soon as the transport exists, and
  /// the first attempt often runs before `connect()` has created it.
  StreamSubscription<bool>? _connectionSub;
  Timer? _retryTimer;
  Timer? _statusRefreshTimer;
  int _retryCount = 0;
  static const int _maxRetries = 10;
  static const Duration _retryDelay = Duration(seconds: 1);
  static const Duration _statusRefreshInterval = Duration(minutes: 1);

  /// Placeholder used only to satisfy field initialisation; replaced in build().
  static DeviceRepository _emptyRepo() => _NullDeviceRepository();

  @override
  LicenseState build() {
    final repo = ref.watch(deviceRepositoryProvider);
    _repo = repo;

    _connectionSub = repo.connectionStream.listen((isConnected) {
      if (isConnected) {
        // Esp8266Repository reports true for every valid telemetry frame. A
        // license handshake is needed only when the transport transitions up,
        // not once per sensor tick.
        if (_connectionKnownUp) return;
        _connectionKnownUp = true;
        _resetRetries();
        unawaited(_refresh());
      } else {
        _connectionKnownUp = false;
        _resetRetries();
        _statusRefreshTimer?.cancel();
        _statusRefreshTimer = null;
        state = state.copyWith(
          status: LicenseDeviceStatus.unknown,
          checkStatus: LicenseCheckStatus.error,
          checkError: 'NETWORK_UNAVAILABLE',
          activationState: LicenseActivationState.idle,
          clearFailure: true,
        );
      }
    });

    ref.onDispose(() {
      _connectionSub?.cancel();
      _retryTimer?.cancel();
      _statusRefreshTimer?.cancel();
    });

    // Kick off the first authoritative query once the transport is ready. It
    // is intentionally asynchronous: the home shell does not wait for this.
    Future<void>.microtask(_refresh);

    return const LicenseState();
  }

  void _resetRetries() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) return;

    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      unawaited(_refresh());
    });
  }

  void _scheduleStatusRefresh() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer(_statusRefreshInterval, () {
      _statusRefreshTimer = null;
      if (_connectionKnownUp) {
        unawaited(_refresh());
      }
    });
  }

  /// Queries the module for its serial and current license status.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;

    // Checking is a visible status, never a route-level loading gate.
    state = state.copyWith(
      checkStatus: LicenseCheckStatus.checking,
      clearCheckError: true,
    );

    try {
      await _readSerial();
      final status = await _readStatus();

      if (status == null) {
        // A transport/query failure is terminal for this attempt. Keep
        // retrying in the background, but expose Error instead of leaving the
        // user on an indefinite "Checking license" page.
        state = state.copyWith(
          status: LicenseDeviceStatus.unknown,
          checkStatus: LicenseCheckStatus.error,
          checkError: 'NO_RESPONSE',
        );
        _scheduleRetry();
        return;
      }

      _retryCount = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      if (_connectionKnownUp) _scheduleStatusRefresh();
    } catch (_) {
      state = state.copyWith(
        status: LicenseDeviceStatus.unknown,
        checkStatus: LicenseCheckStatus.error,
        checkError: 'NETWORK_UNAVAILABLE',
      );
      _scheduleRetry();
    } finally {
      _refreshing = false;
    }
  }

  /// Requests a fresh status without relying on any stored Flutter value.
  Future<void> retryCheck() async {
    _retryCount = 0;
    await _refresh();
  }

  /// Reads and applies the module-reported serial.
  Future<void> _readSerial() async {
    final serial = await _repo.getDeviceSerial();
    if (serial != null) {
      state = state.copyWith(deviceSerial: serial.serial);
    }
  }

  /// Reads and applies the authoritative LICENSE_STATUS from the module.
  ///
  /// [preserveActivation] keeps the current [LicenseActivationState] (used by
  /// the post-activation path so the success flag is not clobbered).
  Future<LicenseStatusMessage?> _readStatus({
    bool preserveActivation = false,
  }) async {
    final status = await _repo.getLicenseStatus();
    if (status == null) return null;

    state = state.copyWith(
      status: status.status,
      licenseType: status.licenseType,
      expires: status.expires,
      checkStatus: licenseCheckStatusFor(status),
      activationState:
          preserveActivation ? null : LicenseActivationState.idle,
      clearFailure: true,
      clearCheckError: true,
    );

    return status;
  }

  /// Activates a license code on the module. On success the module becomes
  /// active and [LicenseNotifier] immediately refreshes its status, so the
  /// protected-control gate can open. Read-only telemetry remains available
  /// before activation. On failure the device stays locked and a mapped,
  /// non-cryptographic failure reason is exposed for the UI.
  Future<void> activateLicense(String code) async {
    state = state.copyWith(
      activationState: LicenseActivationState.loading,
      clearFailure: true,
      checkStatus: LicenseCheckStatus.checking,
      clearCheckError: true,
    );

    final LicenseResultMessage? result;
    try {
      result = await _repo.activateLicense(code);
    } catch (_) {
      state = state.copyWith(
        activationState: LicenseActivationState.failure,
        checkStatus: LicenseCheckStatus.error,
        checkError: 'NO_RESPONSE',
        failureReason: LicenseFailureReason.unknown,
        activationReason: 'NO_RESPONSE',
      );
      return;
    }

    if (result == null) {
      state = state.copyWith(
        activationState: LicenseActivationState.failure,
        checkStatus: LicenseCheckStatus.error,
        checkError: 'NO_RESPONSE',
        failureReason: LicenseFailureReason.unknown,
        activationReason: 'NO_RESPONSE',
      );
      return;
    }

    if (result.ok) {
      state = state.copyWith(
        activationState: LicenseActivationState.success,
        checkStatus: LicenseCheckStatus.checking,
        clearFailure: true,
        clearCheckError: true,
        activationReason: result.reason,
      );

      // The module now holds an active license; re-read the authoritative
      // LICENSE_STATUS before opening protected controls. This is intentionally
      // not a local/cache-based grant.
      final status = await _readStatus(preserveActivation: true);
      if (status == null) {
        state = state.copyWith(
          checkStatus: LicenseCheckStatus.error,
          checkError: 'NO_RESPONSE',
        );
      } else if (_connectionKnownUp) {
        _scheduleStatusRefresh();
      }
    } else {
      final reason = licenseFailureReasonFromFirmware(result.reason);
      state = state.copyWith(
        activationState: LicenseActivationState.failure,
        checkStatus: licenseCheckStatusForFailure(reason),
        failureReason: reason,
        activationReason: result.reason,
      );
    }
  }
}

/// Minimal no-op [DeviceRepository] used before the real one is wired in, so
/// field initialisation never touches a null transport.
class _NullDeviceRepository implements DeviceRepository {
  @override
  Future<void> connect({required String host, int? port}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isConnected() async => false;

  @override
  Future<Map<String, dynamic>> readJson() async => {};

  @override
  Future<void> sendJson(Map<String, dynamic> payload) async {}

  @override
  bool get hasAuthoritativeActiveLicense => false;

  @override
  Stream<DeviceStatus> get liveUpdates => const Stream.empty();

  @override
  Stream<bool> get connectionStream => const Stream.empty();

  @override
  Stream<LicenseMessage> get licenseStream => const Stream.empty();

  @override
  Future<DeviceSerialMessage?> getDeviceSerial() async => null;

  @override
  Future<LicenseStatusMessage?> getLicenseStatus() async => null;

  @override
  Future<LicenseResultMessage?> activateLicense(String code) async => null;

  @override
  Future<void> reconnect() async {}
}
