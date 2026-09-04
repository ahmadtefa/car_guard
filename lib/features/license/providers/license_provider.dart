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
/// never trusts cached Flutter state: on every (re)connection it re-queries
/// `DEVICE_SERIAL` then `LICENSE_STATUS` over the existing WebSocket, and it
/// reseats to [LicenseDeviceStatus.unknown] whenever the link drops.
final licenseProvider = NotifierProvider<LicenseNotifier, LicenseState>(
  LicenseNotifier.new,
);

class LicenseNotifier extends Notifier<LicenseState> {
  DeviceRepository _repo = _emptyRepo();
  bool _refreshing = false;

  /// Retried queries: a LOCKED module broadcasts no telemetry, so the socket
  /// channel may be open before any genuine data proves the link is live. We
  /// still need to send `DEVICE_SERIAL` as soon as the transport exists, and
  /// the first attempt often runs before `connect()` has created it.
  StreamSubscription<bool>? _connectionSub;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 10;
  static const Duration _retryDelay = Duration(seconds: 1);

  /// Placeholder used only to satisfy field initialisation; replaced in build().
  static DeviceRepository _emptyRepo() => _NullDeviceRepository();

  @override
  LicenseState build() {
    final repo = ref.watch(deviceRepositoryProvider);
    _repo = repo;

    // Re-query the authoritative module whenever a (new) connection is up, and
    // fall back to the neutral 'unknown' state whenever the link drops so the
    // app never keeps showing telemetry for a module it can no longer trust.
    _connectionSub = repo.connectionStream.listen((isConnected) {
      if (isConnected) {
        _resetRetries();
        _refresh();
      } else {
        _resetRetries();
        state = state.copyWith(
          status: LicenseDeviceStatus.unknown,
          activationState: LicenseActivationState.idle,
          clearFailure: true,
        );
      }
    });
    ref.onDispose(() {
      _connectionSub?.cancel();
      _retryTimer?.cancel();
    });

    // Kick off the first authoritative query once the transport is ready.
    Future.microtask(_refresh);

    return const LicenseState();
  }

  void _resetRetries() {
    _retryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Queries the module for its serial and current license status.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _readSerial();
      await _readStatus();

      // Still no definitive answer (module not reachable yet / transport not
      // created) — back off and try again so a command is sent as soon as the
      // socket actually opens. A definitive status stops the loop.
      if (state.status == LicenseDeviceStatus.unknown &&
          _retryCount < _maxRetries) {
        _retryCount++;
        _retryTimer?.cancel();
        _retryTimer = Timer(_retryDelay, () {
          // Re-check the counter so the last scheduled attempt does not loop.
          if (_retryCount < _maxRetries) _refresh();
        });
      }
    } catch (_) {
      // Keep the current (unknown / last known) state; a transient failure is
      // recovered on the next connection event.
    } finally {
      _refreshing = false;
    }
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
  /// the post-activation path so the success flag is not clobbered); a normal
  /// connect-driven refresh resets it to idle.
  Future<void> _readStatus({bool preserveActivation = false}) async {
    final status = await _repo.getLicenseStatus();
    if (status != null) {
      state = state.copyWith(
        status: status.status,
        licenseType: status.licenseType,
        expires: status.expires,
        activationState:
            preserveActivation ? null : LicenseActivationState.idle,
        clearFailure: true,
      );
    }
  }

  /// Activates a license code on the module. On success the module becomes
  /// active and [LicenseNotifier] immediately refreshes its status, so the
  /// gate flips back to the dashboard. On failure the device stays locked and
  /// a mapped, non-cryptographic failure reason is exposed for the UI.
  Future<void> activateLicense(String code) async {
    state = state.copyWith(
      activationState: LicenseActivationState.loading,
      clearFailure: true,
    );

    final LicenseResultMessage? result;
    try {
      result = await _repo.activateLicense(code);
    } catch (_) {
      state = state.copyWith(
        activationState: LicenseActivationState.failure,
        failureReason: LicenseFailureReason.unknown,
        activationReason: 'NO_RESPONSE',
      );
      return;
    }

    if (result == null) {
      state = state.copyWith(
        activationState: LicenseActivationState.failure,
        failureReason: LicenseFailureReason.unknown,
        activationReason: 'NO_RESPONSE',
      );
      return;
    }

    if (result.ok) {
      state = state.copyWith(
        activationState: LicenseActivationState.success,
        clearFailure: true,
        activationReason: result.reason,
      );
      // The module now holds an active license; re-read the authoritative
      // LICENSE_STATUS so the gate can switch to the dashboard and telemetry
      // resumes. This is intentionally not guarded by [_refreshing]: a
      // connection-driven refresh that was already in flight must not swallow
      // the post-activation status. The success flag is preserved so the UI can
      // acknowledge it.
      await _readStatus(preserveActivation: true);
    } else {
      state = state.copyWith(
        activationState: LicenseActivationState.failure,
        failureReason: licenseFailureReasonFromFirmware(result.reason),
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
