import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/license/providers/license_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../services/device_models.dart';
import 'demo_device_provider.dart';
import 'device_provider.dart';

/// Streams data that is safe for the rest of the app to consume.
///
/// This is the source-level license boundary, not a dashboard visibility
/// choice. Real repository telemetry is subscribed to only after the ESP8266
/// reports ACTIVE on the current WebSocket session. Before that (including
/// Checking, Error and settings-loading), consumers receive one neutral
/// disconnected value, so analysis, alerts, history and widgets cannot process
/// real readings. Demo mode is the only intentional non-licensed source and
/// uses the built-in simulator exclusively.
final deviceStatusProvider = StreamProvider<DeviceStatus>((ref) {
  final settingsReady = ref.watch(
    settingsProvider.select((value) => value.value != null),
  );
  final demoEnabled = ref.watch(
    settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
  );

  // Deny by default while persisted settings are still loading. This avoids
  // exposing a live stream for a moment before a saved Demo flag is known.
  if (!settingsReady) {
    return Stream<DeviceStatus>.value(DeviceStatus.disconnected());
  }

  if (demoEnabled) {
    final simulator = ref.watch(demoDeviceSimulatorProvider);

    simulator.start();

    return simulator.statusStream;
  }

  final licenseAuthorized = ref.watch(licenseAuthorizationProvider);
  if (!licenseAuthorized) {
    return Stream<DeviceStatus>.value(DeviceStatus.disconnected());
  }

  final repository = ref.watch(deviceRepositoryProvider);

  // Re-check the current authorization at emission time as well as at stream
  // construction. This closes the small race where a sensor frame is already
  // queued while the license state is transitioning away from ACTIVE.
  return repository.liveUpdates.where((_) {
    final currentSettings = ref.read(settingsProvider).value;
    return repository.hasAuthoritativeActiveLicense &&
        currentSettings != null &&
        !currentSettings.demoModeEnabled &&
        ref.read(licenseAuthorizationProvider);
  });
});
