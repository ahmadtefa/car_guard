import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../services/device_models.dart';
import 'demo_device_provider.dart';
import 'device_provider.dart';

/// Streams live device readings.
///
/// When demo mode is enabled in settings the stream comes from the built-in
/// simulator instead of the ESP8266 repository, letting the whole app (cards,
/// charts, alerts, notifications) run without physical hardware.
final deviceStatusProvider = StreamProvider<DeviceStatus>((ref) {
  final demoEnabled = ref.watch(
    settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
  );

  if (demoEnabled) {
    final simulator = ref.watch(demoDeviceSimulatorProvider);

    simulator.start();

    return simulator.statusStream;
  }

  final repository = ref.watch(esp8266RepositoryProvider);

  return repository.liveUpdates;
});
