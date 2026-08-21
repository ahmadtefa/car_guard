import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../services/device_models.dart';
import 'device_status_provider.dart';

/// Overrides the local alarm thresholds with the limits reported by the
/// module. When the module reports a limit, alerts fire exactly at that
/// limit — the module is the single source of truth (no invented warning
/// tier, no legacy local slider values).
AppSettings applyModuleLimits(AppSettings local, ModuleLimits limits) {
  if (limits.isEmpty) return local;

  var effective = local;

  if (limits.maxTemp != null) {
    effective = effective.copyWith(
      engineTempCritical: limits.maxTemp,
      engineTempWarning: limits.maxTemp,
    );
  }

  if (limits.minVolt != null) {
    effective = effective.copyWith(minBatteryVoltage: limits.minVolt);
  }

  if (limits.maxVolt != null) {
    effective = effective.copyWith(maxBatteryVoltage: limits.maxVolt);
  }

  return effective;
}

/// Merges the locally configured settings with the alarm limits the module
/// reports in its live stream, mirroring the original Kayan dashboard where
/// device-borne limits win over the saved ones.
///
/// When the module does not send any limits (or nothing is connected) the
/// local settings are returned untouched.
final effectiveSettingsProvider = Provider<AppSettings>((ref) {
  final local = ref.watch(settingsProvider).value ?? const AppSettings();

  final limits =
      ref.watch(deviceStatusProvider).value?.moduleLimits ??
      const ModuleLimits();

  return applyModuleLimits(local, limits);
});
