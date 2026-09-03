import 'dart:async';
import 'dart:math' as math;

import 'device_models.dart';

/// Internal state advanced by [DemoDeviceEngine.tick] on every simulated
/// second.
class DemoDeviceState {
  const DemoDeviceState({
    this.engineTemperature = 72,
    this.fanRunning = false,
    this.batteryVoltage = 12.8,
    this.coolantAvailable = true,
    this.buzzerActive = false,
    this.fanForced = false,
    this.tick = 0,
  });

  final double engineTemperature;
  final bool fanRunning;
  final double batteryVoltage;
  final bool coolantAvailable;
  final bool buzzerActive;

  /// Mirrors the module-side forced fan mode, so the demo exercises exactly the
  /// same state path as real hardware (the flag travels in [toDeviceStatus]).
  final bool fanForced;

  /// Simulation step counter; used for deterministic pseudo-noise.
  final int tick;

  /// Maps the simulated state onto the real [DeviceStatus] model so the rest
  /// of the app cannot tell the demo device from a physical module.
  DeviceStatus toDeviceStatus() {
    return DeviceStatus(
      connected: true,
      deviceId: 'Car Guard (Demo)',
      batteryData: BatteryData(
        voltage: batteryVoltage,
        voltageDifference: (tick % 7) * 0.05,
      ),
      temperatureData: TemperatureData(
        engineTemperature: engineTemperature,
      ),
      coolantLevelData: CoolantLevelData(coolantAvailable: coolantAvailable),
      controlData: DeviceControlData(
        fanRunning: fanRunning,
        buzzerActive: buzzerActive,
        fanForced: fanForced,
      ),
      // The demo reports fixed module limits (like real firmware) so
      // temperature/voltage alerts and gauge redlines stay explorable.
      moduleLimits: const ModuleLimits(
        maxTemp: 95,
        fanOnTemp: 85,
        minVolt: 12.0,
        maxVolt: 15.0,
      ),
      lastUpdated: DateTime.now(),
    );
  }
}

/// Deterministic, side-effect-free simulation of the Car Guard module.
///
/// Keeping the transition pure makes the scenario testable without timers:
/// heat rises while the fan is off, the thermostat switches the fan on late
/// (112 °C) so the critical alert threshold (110 °C) is occasionally crossed,
/// and the alternator slowly swings the battery voltage into the low range.
abstract final class DemoDeviceEngine {
  static const double _fanOnTemperature = 112;
  static const double _fanOffTemperature = 82;

  static DemoDeviceState tick(DemoDeviceState state) {
    final nextTick = state.tick + 1;

    var fanRunning = state.fanRunning;
    if (state.fanForced) {
      // Same rule as the firmware: forced mode outranks the thermostat, and
      // releasing it hands the decision back without forcing the fan off.
      fanRunning = true;
    } else if (state.engineTemperature >= _fanOnTemperature) {
      fanRunning = true;
    } else if (state.engineTemperature <= _fanOffTemperature) {
      fanRunning = false;
    }

    // Deterministic pseudo-noise keeps readings looking organic on a chart.
    final drift = (state.tick % 4) * 0.15 - 0.2;

    var temperature =
        state.engineTemperature + (fanRunning ? -1.3 : 0.95) + drift;

    if (temperature < 40) temperature = 40;
    if (temperature > 125) temperature = 125;

    // Alternator cycle: slowly swings between ~11.6 V and ~13.4 V so the
    // low-battery alert (default <= 12.2 V) fires from time to time.
    final voltage =
        12.5 + 0.9 * math.sin(state.tick / 40) + (state.tick % 3) * 0.02;

    // Brief low-coolant window (~15s) roughly every three minutes.
    final coolantAvailable = state.tick % 180 < 165;

    return DemoDeviceState(
      engineTemperature: temperature,
      fanRunning: fanRunning,
      batteryVoltage: voltage,
      coolantAvailable: coolantAvailable,
      buzzerActive: temperature >= 108,
      fanForced: state.fanForced,
      tick: nextTick,
    );
  }
}

/// Emits a live [DeviceStatus] every [interval], simulating a physical
/// Car Guard module for demo purposes.
class DemoDeviceSimulator {
  DemoDeviceSimulator({this.interval = const Duration(seconds: 1)});

  final Duration interval;

  final StreamController<DeviceStatus> _controller =
      StreamController<DeviceStatus>.broadcast();

  Timer? _timer;
  DemoDeviceState _state = const DemoDeviceState();

  /// Broadcast stream of simulated readings; safe to listen to repeatedly.
  Stream<DeviceStatus> get statusStream => _controller.stream;

  /// Starts emitting; calling an already running simulator is a no-op.
  void start() {
    _timer ??= Timer.periodic(interval, (_) {
      _state = DemoDeviceEngine.tick(_state);
      _controller.add(_state.toDeviceStatus());
    });
  }


  /// Demo counterpart of the module's `/fanforce` + `/fanrelease`: the flag is
  /// stored in the simulated device state and pushed back through the stream,
  /// so the UI is driven by the "device" in demo mode exactly like it is with
  /// hardware — never by an optimistic local guess.
  Future<bool> setFanForced(bool enabled) async {
    _state = DemoDeviceState(
      engineTemperature: _state.engineTemperature,
      batteryVoltage: _state.batteryVoltage,
      coolantAvailable: _state.coolantAvailable,
      buzzerActive: _state.buzzerActive,
      fanForced: enabled,
      fanRunning: enabled ? true : _state.fanRunning,
      tick: _state.tick,
    );

    if (_controller.hasListener) {
      _controller.add(_state.toDeviceStatus());
    }

    return true;
  }

  /// Stops emitting but keeps the stream open for a later [start].
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops the simulator and closes the stream.
  void dispose() {
    stop();
    _controller.close();
  }
}
