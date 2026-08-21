import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reading_sample.dart';
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
