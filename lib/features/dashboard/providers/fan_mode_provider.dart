import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/providers/demo_device_provider.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import '../../settings/providers/settings_provider.dart';

/// How the radiator fan is being driven.
///
/// Only two modes exist because the *automatic* one is the firmware's own
/// temperature algorithm, which this feature must never replace: `forcedOn`
/// simply pins the fan on while that algorithm keeps running untouched.
enum FanMode { automatic, forcedOn }

/// Outcome of a fan-mode command, so the UI can tell the truth to the user.
enum FanCommandResult {
  /// The module answered `OK` and the live stream now shows the new mode.
  confirmed,

  /// The module answered `OK` but the flag has not come back in the stream
  /// yet (a slow link). The UI reports it as "sent, not confirmed" instead of
  /// pretending the fan is in that mode.
  sentUnconfirmed,

  /// No connection to the module, or it refused / did not answer.
  failed,

  /// The app is not talking to a module at all right now.
  notConnected,
}

/// Fan control state shown by the dashboard.
///
/// [mode] is never an optimistic local guess: it mirrors what the module
/// reported in its live stream, which is what keeps the ESP8266 state, the
/// forced flag and the automatic control from ever disagreeing on screen.
class FanModeState {
  const FanModeState({
    this.mode = FanMode.automatic,
    this.modeReported = false,
    this.pending = false,
    this.connected = false,
  });

  final FanMode mode;

  /// False when the connected firmware does not report `fanForced` at all,
  /// i.e. too old to support the feature.
  final bool modeReported;

  /// True while a command is in flight.
  final bool pending;

  final bool connected;

  bool get forced => mode == FanMode.forcedOn;

  FanModeState copyWith({
    FanMode? mode,
    bool? modeReported,
    bool? pending,
    bool? connected,
  }) {
    return FanModeState(
      mode: mode ?? this.mode,
      modeReported: modeReported ?? this.modeReported,
      pending: pending ?? this.pending,
      connected: connected ?? this.connected,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FanModeState &&
        other.mode == mode &&
        other.modeReported == modeReported &&
        other.pending == pending &&
        other.connected == connected;
  }

  @override
  int get hashCode => Object.hash(mode, modeReported, pending, connected);
}

/// Owns the forced-fan command: UI → this notifier → repository → ESP8266.
///
/// The widget layer never touches HTTP itself; everything goes through
/// [Esp8266Repository.setFanForced] (or the demo simulator, mirroring
/// `deviceStatusProvider`'s own source switch), and the resulting mode is read
/// back from the module stream rather than remembered locally.
///
/// Riverpod 3 rebuilds a `Notifier` whenever it is invalidated and forbids using
/// its `Ref` after it was replaced, so this class only touches `ref` inside
/// [build] and from synchronous entry points: the confirmation of a command is
/// awaited on a [Completer] that the stream listener completes, never by
/// reading providers across an `await`.
class FanModeNotifier extends Notifier<FanModeState> {
  /// How long to wait for the module to echo the new flag in its stream.
  static const Duration _confirmTimeout = Duration(seconds: 4);

  /// The most recent reading this notifier has seen from the module stream.
  ///
  /// Kept here (instead of re-reading the provider) so that a command that
  /// finishes after the dashboard went away can still be evaluated — and so
  /// that no `Ref` use is ever needed after an `await`.
  DeviceStatus? _lastDevice;

  /// Completed by the stream listener on the next module reading, which is how
  /// a pending command learns that its flag arrived. It is completed with
  /// `false` when the wait is abandoned (failure, disconnect, disposal).
  Completer<bool>? _changed;

  bool _disposed = false;

  @override
  FanModeState build() {
    _disposed = false;
    _lastDevice = ref.read(deviceStatusProvider).value;

    ref.onDispose(() {
      _disposed = true;
      _resolveWaiter(false);
    });

    // The module stream is the single source of truth: every reading refreshes
    // the mode, so a manual change made from the Android Auto screen, another
    // phone, or the module itself is reflected here without extra plumbing.
    //
    // `listen` (rather than `watch`) on purpose: the reading arrives about
    // every second, and the notifier must not be recreated that often — a
    // command would lose the state of its in-flight confirmation.
    ref.listen<AsyncValue<DeviceStatus>>(deviceStatusProvider, (_, next) {
      _lastDevice = next.value;
      _resolveWaiter();
      state = _derive(next.value, pending: state.pending);
    });

    return _derive(_lastDevice, pending: false);
  }

  /// Requests forced-ON (`enabled == true`) or hands the fan back to the
  /// module's automatic control (`enabled == false`).
  Future<FanCommandResult> setForced(bool enabled) async {
    if (state.pending) {
      return FanCommandResult.failed;
    }

    final device = ref.read(deviceStatusProvider).value;

    if (device == null || !device.connected) {
      return FanCommandResult.notConnected;
    }

    final waiter = Completer<bool>();
    _changed = waiter;
    _lastDevice = device;
    state = _derive(device, pending: true);

    final bool acknowledged;

    try {
      acknowledged = await _send(enabled);
    } catch (_) {
      // A transport that throws (socket torn down mid-request) is a failed
      // command, never a success the UI would have to walk back.
      _resolveWaiter(false);
      _refresh(pending: false);

      return FanCommandResult.failed;
    }

    if (!acknowledged) {
      // The module did not answer with `OK`: nothing was applied, so the UI is
      // told it failed and the reported mode stays whatever the stream says.
      _resolveWaiter(false);
      _refresh(pending: false);

      return FanCommandResult.failed;
    }

    // The acknowledgement only proves the HTTP handler answered. The mode
    // itself is confirmed when the flag shows up in the live stream, which is
    // what the UI displays.
    if (!_matches(_lastDevice, enabled)) {
      final bool arrived = await waiter.future
          .timeout(_confirmTimeout, onTimeout: () => false);

      if (!arrived) {
        _resolveWaiter(false);
        _refresh(pending: false);

        return FanCommandResult.sentUnconfirmed;
      }
    }

    _resolveWaiter();
    _refresh(pending: false);

    return _matches(_lastDevice, enabled)
        ? FanCommandResult.confirmed
        : FanCommandResult.sentUnconfirmed;
  }

  /// Sends the command through the repository layer — the demo simulator when
  /// demo mode is on, so the demo exercises the exact same "the device reports
  /// its mode back" path as real hardware.
  Future<bool> _send(bool enabled) {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();

    if (settings.demoModeEnabled) {
      return ref.read(demoDeviceSimulatorProvider).setFanForced(enabled);
    }

    return ref.read(esp8266RepositoryProvider).setFanForced(enabled);
  }

  /// Lets whoever is waiting for a stream update know about it, and always
  /// clears the field so a later command can not reuse a completed waiter.
  void _resolveWaiter([bool arrived = true]) {
    final waiter = _changed;
    _changed = null;

    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(arrived);
    }
  }

  /// Re-reads the module state unless this notifier was already disposed (a
  /// command can land after the dashboard was torn down).
  void _refresh({required bool pending}) {
    if (_disposed) {
      return;
    }

    state = _derive(_lastDevice, pending: pending);
  }

  static bool _matches(DeviceStatus? device, bool enabled) {
    return device != null && device.controlData.fanForced == enabled;
  }

  /// Full rebuild from the module reading: no field is ever inherited from the
  /// previous state, so a stale value can not survive a disconnect or a reboot
  /// of the module.
  FanModeState _derive(DeviceStatus? device, {required bool pending}) {
    final forced = device?.controlData.fanForced ?? false;

    return FanModeState(
      mode: forced ? FanMode.forcedOn : FanMode.automatic,
      modeReported: device?.controlData.fanForced != null,
      pending: pending,
      connected: device?.connected ?? false,
    );
  }
}

/// Live fan mode + the command path for the manual override.
final fanModeProvider = NotifierProvider<FanModeNotifier, FanModeState>(
  FanModeNotifier.new,
);
