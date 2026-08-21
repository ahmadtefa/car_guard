import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../models/app_settings.dart';
import 'device_status_provider.dart';

/// Merges the locally configured settings with the alarm limits the module
/// reports in its live stream, mirroring the original Kayan dashboard where
/// device-borne limits win over the saved ones.
///
/// When the module does not send any limits (or nothing is connected) the
/// local settings are returned untouched.
final effectiveSettingsProvider = Provider<AppSettings>((ref) {
  final local = ref.watch(settingsProvider).value ?? const AppSettings();

  final limits = ref.watch(deviceStatusProvider).value?.moduleLimits;

  if (limits == null || limits.isEmpty) {
    return local;
  }

  var effective = local;

  if (limits.maxTemp != null) {
    effective = effective.copyWith(
      engineTempCritical: limits.maxTemp,
      engineTempWarning: limits.maxTemp! - 5 < local.engineTempWarning
          ? limits.maxTemp! - 5
          : local.engineTempWarning,
    );
  }

  if (limits.minVolt != null) {
    effective = effective.copyWith(minBatteryVoltage: limits.minVolt);
  }

  if (limits.maxVolt != null) {
    effective = effective.copyWith(maxBatteryVoltage: limits.maxVolt);
  }

  return effective;
});
