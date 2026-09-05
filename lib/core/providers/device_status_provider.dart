import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../services/device_models.dart';
import 'demo_device_provider.dart';
import 'device_provider.dart';

/// Streams live device readings.
///
/// License authorization is deliberately not a read-only data gate. The
/// firmware keeps temperature/voltage telemetry available while LOCKED; only
/// protected writes and control features require an authoritative ACTIVE
/// license. Demo mode continues to use the built-in simulator.
final deviceStatusProvider = StreamProvider<DeviceStatus>((ref) {
  final settingsReady = ref.watch(
    settingsProvider.select((value) => value.value != null),
  );
  final demoEnabled = ref.watch(
    settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
  );

  // Deny by default while persisted settings are still loading so a saved
  // Demo flag cannot be bypassed for one frame during startup.
  if (!settingsReady) {
    return Stream<DeviceStatus>.value(DeviceStatus.disconnected());
  }

  if (demoEnabled) {
    final simulator = ref.watch(demoDeviceSimulatorProvider);

    simulator.start();

    return simulator.statusStream;
  }

  final repository = ref.watch(deviceRepositoryProvider);
  return repository.liveUpdates;
});
