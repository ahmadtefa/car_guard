import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/device_models.dart';
import 'device_status_provider.dart';

/// Thresholds used by the gauges/HUD to draw redlines and color warnings.
///
/// The app-side threshold sliders were removed *together with their effect*:
/// the base is always a default [AppSettings] (never the user's stored
/// values), overlaid with the limits the module reports in its live stream.
/// Actual alerting is evaluated against the module limits directly — see
/// [AlertEvaluator].
final effectiveSettingsProvider = Provider<AppSettings>((ref) {
  final limits = ref.watch(deviceStatusProvider).value?.moduleLimits;

  return mergeModuleLimits(const AppSettings(), limits);
});
