import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reading_sample.dart';
import '../../../core/providers/device_status_provider.dart';
import 'readings_history_provider.dart';

/// Computes the battery voltage change over the recent window.
///
/// Compares the newest sample with the oldest sample inside [lookback]
/// (falling back to the very first sample of the session). Returns null
/// until at least two samples exist.
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

  return latest.batteryVoltage - reference.batteryVoltage;
}

/// Live voltage delta (V) for the dashboard gauge.
final voltageDeltaProvider = Provider<double?>((ref) {
  return computeVoltageDelta(ref.watch(readingsHistoryProvider));
});

/// The voltage difference shown by every dashboard gauge style.
///
/// Prefers the value streamed by the module itself (firmware builds that
/// send `voltDiff`/`voltageDifference`). Firmware that streams no such
/// field — including the stock Car Guard CSV/JSON payloads — leaves it
/// null, so the gauges fall back to the delta computed from the live
/// battery-voltage history: a real value derived from live telemetry
/// rather than a synthetic zero. Null (empty gauge) only until either
/// source has data.
final dashboardVoltageDeltaProvider = Provider<double?>((ref) {
  final reported = ref
      .watch(deviceStatusProvider)
      .value
      ?.batteryData
      .voltageDifference;

  if (reported != null) return reported;

  return ref.watch(voltageDeltaProvider);
});
