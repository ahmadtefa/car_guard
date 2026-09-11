import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reading_sample.dart';
import '../../../core/providers/device_status_provider.dart';
import 'readings_history_provider.dart';

/// Computes the battery voltage change over the recent window.
///
/// Compares the newest sample with the oldest sample inside [lookback]
/// (falling back to the very first sample of the session). Returns null
/// until at least two samples exist.
///
/// The history fallback always returns the absolute value to ensure
/// a negative voltage difference is never displayed as negative.
double? computeVoltageDelta(
  List<ReadingSample> history, {
  Duration lookback = const Duration(seconds: 90),
}) {
  if (history.length < 2) return null;

  final latest = history.last;

  ReadingSample? reference;

  for (final sample in history) {
    if (!sample.timestamp.isBefore(latest.timestamp.subtract(lookback))) {
      reference = sample;
      break;
    }
  }

  reference ??= history.first;

  if (reference.timestamp.isAtSameMomentAs(latest.timestamp)) return null;

  // Return absolute value to ensure result is never negative from history fallback.
  return (latest.batteryVoltage - reference.batteryVoltage).abs();
}

/// Applies the dashboard's voltage-difference source order:
///
/// 1. a finite module-reported value, including a legitimate zero;
/// 2. the locally calculated 90-second history delta (always absolute);
/// 3. null while there is not enough information.
///
/// A negative module-reported value is converted to its absolute value
/// to ensure it is never displayed as negative.
double? resolveVoltageDelta({
  required double? moduleDelta,
  required List<ReadingSample> history,
  Duration lookback = const Duration(seconds: 90),
}) {
  if (moduleDelta != null && moduleDelta.isFinite) {
    return moduleDelta.abs();
  }
  return computeVoltageDelta(history, lookback: lookback);
}

/// Effective live voltage delta (V) for the dashboard gauge.
///
/// The repository keeps a missing module field as null. This provider is the
/// single place where the history fallback is selected, so the card and the
/// dashboard state cannot accidentally diverge or turn an unavailable value
/// into zero.
///
/// The returned value is always non-negative.
final voltageDeltaProvider = Provider<double?>((ref) {
  // Keep history subscribed even while the status stream is loading or
  // disconnected. Otherwise the first connected frame can arrive before the
  // history listener is created, leaving the fallback with too few samples.
  final history = ref.watch(readingsHistoryProvider);
  final device = ref.watch(deviceStatusProvider).value;
  if (device == null || !device.connected) return null;

  return resolveVoltageDelta(
    moduleDelta: device.batteryData.voltageDifference,
    history: history,
  );
});
