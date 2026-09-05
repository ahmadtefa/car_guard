import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../services/device_models.dart';
import '../../features/license/providers/license_provider.dart';
import 'demo_device_provider.dart';
import 'device_provider.dart';

/// Streams live device readings.
///
/// Real-module telemetry is gated by the authoritative ACTIVE license proof.
/// Demo mode continues to use the built-in simulator independently, while a
/// locked/expired real module emits a disconnected/empty status so consumers
/// cannot retain or display stale readings.
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
  final licenseAuthorized = ref.watch(licenseAuthorizationProvider);

  // Keep license protocol traffic available through the repository, but do
  // not expose the real-module sensor stream until the current session has a
  // fresh ACTIVE proof. The disconnected value clears every UI consumer.
  if (!licenseAuthorized) {
    return Stream<DeviceStatus>.value(DeviceStatus.disconnected());
  }

  return repository.liveUpdates;
});
