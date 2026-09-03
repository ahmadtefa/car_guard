import 'dart:async';

import 'package:car_guard/core/providers/device_provider.dart';
import 'package:car_guard/core/providers/device_status_provider.dart';
import 'package:car_guard/core/services/device_models.dart';
import 'package:car_guard/core/services/esp8266_repository.dart';
import 'package:car_guard/features/dashboard/providers/fan_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A module that answers commands on demand, without any sockets involved.
class _FakeRepository extends Esp8266Repository {
  _FakeRepository() : super(host: '127.0.0.1');

  /// What the fake module replied to each `/fanforce` / `/fanrelease`.
  final List<bool> requests = <bool>[];

  bool acknowledges = true;

  @override
  Future<bool> setFanForced(bool enabled) async {
    requests.add(enabled);

    return acknowledges;
  }
}

DeviceStatus _status({
  bool connected = true,
  bool? fanForced = false,
  bool fanRunning = false,
}) {
  return DeviceStatus(
    connected: connected,
    deviceId: 'fake',
    batteryData: const BatteryData(voltage: 13.9),
    temperatureData: const TemperatureData(engineTemperature: 88),
    coolantLevelData: const CoolantLevelData(),
    controlData: DeviceControlData(
      fanRunning: fanRunning,
      fanForced: fanForced,
    ),
    lastUpdated: DateTime(2026, 9, 3),
  );
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<DeviceStatus> deviceStream;
  late _FakeRepository repository;
  late ProviderContainer container;

  Future<void> boot({List<DeviceStatus> initial = const []}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    deviceStream = StreamController<DeviceStatus>.broadcast();
    repository = _FakeRepository();

    container = ProviderContainer(
      overrides: <Override>[
        esp8266RepositoryProvider.overrideWithValue(repository),
        deviceStatusProvider.overrideWith((ref) => deviceStream.stream),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await deviceStream.close();
    });

    container.listen(fanModeProvider, (_, _) {});

    for (final status in initial) {
      deviceStream.add(status);
    }

    await _settle();
  }

  test('the mode follows the module, not an optimistic local guess', () async {
    await boot(initial: [_status(fanForced: false, fanRunning: false)]);

    expect(container.read(fanModeProvider).mode, FanMode.automatic);
    expect(container.read(fanModeProvider).forced, isFalse);

    deviceStream.add(_status(fanForced: true, fanRunning: true));
    await _settle();

    expect(container.read(fanModeProvider).mode, FanMode.forcedOn);
    expect(container.read(fanModeProvider).forced, isTrue);
  });

  test('a firmware that does not report the flag shows it as unknown', () async {
    await boot(initial: [_status(fanForced: null)]);

    final state = container.read(fanModeProvider);

    expect(state.modeReported, isFalse);
    // "Unknown" must never be rendered as a confident "automatic".
    expect(state.mode, FanMode.automatic);
    expect(state.forced, isFalse);
  });

  test('confirmed command: ack plus the flag coming back in the stream', () async {
    await boot(initial: [_status(fanForced: false)]);

    final future = container.read(fanModeProvider.notifier).setForced(true);

    await _settle();

    expect(repository.requests, <bool>[true]);

    deviceStream.add(_status(fanForced: true, fanRunning: true));

    expect(await future, FanCommandResult.confirmed);

    final state = container.read(fanModeProvider);

    expect(state.pending, isFalse);
    expect(state.mode, FanMode.forcedOn);
  });

  test('release command sends false and returns the fan to automatic', () async {
    await boot(initial: [_status(fanForced: true, fanRunning: true)]);

    final future = container.read(fanModeProvider.notifier).setForced(false);

    await _settle();

    expect(repository.requests, <bool>[false]);

    deviceStream.add(_status(fanForced: false, fanRunning: true));

    expect(await future, FanCommandResult.confirmed);
    expect(container.read(fanModeProvider).mode, FanMode.automatic);
  });

  test('a module that does not acknowledge leaves the state untouched', () async {
    await boot(initial: [_status(fanForced: false)]);

    repository.acknowledges = false;

    final result = await container
        .read(fanModeProvider.notifier)
        .setForced(true);

    expect(result, FanCommandResult.failed);

    final state = container.read(fanModeProvider);

    expect(state.mode, FanMode.automatic);
    expect(state.pending, isFalse);
  });

  test('no connection: the command is refused before anything is sent', () async {
    await boot(initial: [_status(connected: false, fanForced: false)]);

    final result = await container
        .read(fanModeProvider.notifier)
        .setForced(true);

    expect(result, FanCommandResult.notConnected);
    expect(repository.requests, isEmpty);
    expect(container.read(fanModeProvider).pending, isFalse);
  });
}
