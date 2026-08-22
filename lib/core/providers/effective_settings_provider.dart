import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../services/device_models.dart';
import 'device_status_provider.dart';

/// Thresholds + preferences used by the gauges/HUD to draw redlines, color
/// warnings and pick the gauge style.
///
/// The base is the user's real settings (so gauge style / theme / language
/// choices apply). The legacy slider thresholds can NOT leak through it:
/// [AppSettings.fromJson] no longer loads the legacy keys, so the locally
/// stored values are always the defaults, overlaid here with the limits the
/// module reports. Actual alerting evaluates the module limits directly —
/// see [AlertEvaluator].
final effectiveSettingsProvider = Provider<AppSettings>((ref) {
  final local = ref.watch(settingsProvider).value ?? const AppSettings();

  final limits = ref.watch(deviceStatusProvider).value?.moduleLimits;

  return mergeModuleLimits(local, limits);
});
