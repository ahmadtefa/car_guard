import 'dart:math' as math;

import '../../../core/models/reading_sample.dart';
import '../models/analysis_models.dart';

/// The event a tracker update wants the outer world to react to.
enum AlertTrackerEvent {
  /// Episode just opened — log it and (if severe) notify.
  started,

  /// Episode persisted past the cooldown — escalate one tier, update the
  /// existing log entry, and re-notify.
  escalated,

  /// Condition cleared — episode closed quietly.
  cleared,
}

/// Tracks one episode per alert kind:
///
/// * a fresh condition opens an episode and logs it ONCE;
/// * while it persists, the entry is only refreshed — no spam;
/// * after [cooldown] of persistence, one refire escalates the tier and
///   updates THE SAME log entry;
/// * once the condition has been absent for [clearAfter], the episode
///   closes and a future condition starts a brand new entry.
class SmartAlertTracker {
  SmartAlertTracker({
    this.cooldown = const Duration(minutes: 10),
    this.clearAfter = const Duration(seconds: 45),
  });

  final Duration cooldown;
  final Duration clearAfter;

  final Map<AnalysisAlertKind, AnalysisAlert> active = {};

  /// When each kind's condition first went false — the episode only
  /// closes after the condition has been absent for [clearAfter],
  /// however long it had been firing before that.
  final Map<AnalysisAlertKind, DateTime> _falseSince = {};

  /// Feeds one evaluation cycle. [severity] is the tier the rule itself
  /// assigns; the tracker may escalate beyond it on refires.
  AlertTrackerEvent? update(
    AnalysisAlertKind kind, {
    required bool condition,
    required AnalysisSeverity severity,
    required DateTime now,
    Map<String, double> readings = const {},
    void Function(AnalysisAlert alert, AlertTrackerEvent event)? onEvent,
  }) {
    final current = active[kind];

    if (!condition) {
      if (current == null) return null;

      final falseSince = (_falseSince[kind] ??= now);
      if (now.difference(falseSince) >= clearAfter) {
        active.remove(kind);
        _falseSince.remove(kind);
        onEvent?.call(current, AlertTrackerEvent.cleared);
        return AlertTrackerEvent.cleared;
      }
      return null;
    }

    _falseSince.remove(kind);

    if (current == null) {
      final alert = AnalysisAlert(
        kind: kind,
        severity: severity,
        startedAt: now,
        updatedAt: now,
        occurrences: 1,
        readings: readings,
      );
      active[kind] = alert;
      onEvent?.call(alert, AlertTrackerEvent.started);
      return AlertTrackerEvent.started;
    }

    // The condition still holds: how long has this ONE episode been
    // going? Escalate at most once per cooldown window.
    final sinceLastFire = now.difference(current.updatedAt);
    if (sinceLastFire >= cooldown) {
      final escalated = current.copyWith(
        severity: current.severity.escalated,
        updatedAt: now,
        occurrences: current.occurrences + 1,
        readings: readings,
      );
      active[kind] = escalated;
      onEvent?.call(escalated, AlertTrackerEvent.escalated);
      return AlertTrackerEvent.escalated;
    }

    // Quiet refresh of the episode (new readings, same entry).
    active[kind] = current.copyWith(readings: readings);
    return null;
  }

  /// Currently open episodes, most severe first.
  List<AnalysisAlert> activeAlerts() {
    final list = active.values.toList()
      ..sort((a, b) => b.severity.rank.compareTo(a.severity.rank));
    return list;
  }
}

/// Pure, side-effect-free analysis rules — unit-testable without a device,
/// a widget tree, or storage. The Riverpod notifier only feeds data in and
/// renders what comes out.
abstract final class AnalysisEngine {
  /// A temperature trend faster than this is "rising".
  static const double risingSlopeCPerMin = 0.25;

  /// A temperature trend faster than this sustained for the slope window
  /// means "rising faster than usual" when it also beats the baseline.
  static const double fastRiseRatio = 1.5;

  /// |90-second voltage change| above this counts as abnormal behaviour.
  static const double abnormalVoltageDeltaV = 0.8;

  /// Fan running continuously longer than this is "longer than usual".
  static const Duration fanLongRunAfter = Duration(minutes: 10);

  /// "High temperature" for the traffic-jam correlation starts here.
  static const double heatCorrelationTempOffsetC = 5;

  /// Vehicle speeds below this count as traffic/idle for the correlation.
  static const double slowSpeedKmh = 12;

  // ------------------------------------------------------------------
  // Slope / rate of change
  // ------------------------------------------------------------------

  /// Temperature rate of change in °C/min over the trailing [window],
  /// computed from the recent samples with a simple least-squares fit so
  /// one noisy spike never fakes a trend. Returns null with < 5 samples.
  static double? computeTempSlopeCPerMin(
    List<ReadingSample> history, {
    Duration window = const Duration(minutes: 2),
  }) {
    if (history.length < 5) return null;

    final latest = history.last;
    final from = latest.timestamp.subtract(window);

    // Samples inside the window (fall back to whatever exists).
    final points = <ReadingSample>[];
    for (final sample in history) {
      if (!sample.timestamp.isBefore(from)) points.add(sample);
    }
    if (points.length < 5) {
      points
        ..clear()
        ..addAll(history.sublist(math.max(0, history.length - 5)));
    }

    final t0 = points.first.timestamp;
    final x = points
        .map((p) => p.timestamp.difference(t0).inMilliseconds / 60000.0)
        .toList();
    final y = points.map((p) => p.engineTemperature).toList();

    final n = points.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;

    var sxx = 0.0, sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sxx += (x[i] - meanX) * (x[i] - meanX);
      sxy += (x[i] - meanX) * (y[i] - meanY);
    }

    if (sxx < 1e-9) return 0;
    return sxy / sxx;
  }

  // ------------------------------------------------------------------
  // By-the-numbers comparison vs the baseline
  // ------------------------------------------------------------------

  /// Absolute difference now vs the baseline + a plain statement; the UI
  /// renders "higher than usual by X°C" only when usable.
  static double? tempVsBaseline(double currentTemp, BaselineStats baseline) {
    if (!baseline.isUsable) return null;
    return currentTemp - baseline.avgTemp;
  }

  static double? voltVsBaseline(double currentVolt, BaselineStats baseline) {
    if (!baseline.isUsable) return null;
    return currentVolt - baseline.avgVoltage;
  }

  // ------------------------------------------------------------------
  // Prediction rules — probabilistic wording only, never a diagnosis
  // ------------------------------------------------------------------

  /// Runs every prediction rule against the current data.
  ///
  /// Confidence is always derived from data quantities (sample counts,
  /// observed minutes, ratios) — never invented. A rule that lacks data
  /// either stays silent or reports confidence == null, which the UI shows
  /// as "insufficient data for analysis".
  static List<Prediction> buildPredictions({
    required double currentTemp,
    required double? slopeCPerMin,
    required double? maxTemp,
    required double? voltageDelta90s,
    required double currentVoltage,
    required SessionStats stats,
    required BaselineStats baseline,
    required int slopeSampleCount,
  }) {
    final predictions = <Prediction>[];

    // 1) Overheat likely soon: positive slope + known limit + distance.
    if (slopeCPerMin != null && maxTemp != null && currentTemp > 0) {
      if (slopeCPerMin > risingSlopeCPerMin && maxTemp - currentTemp < 12) {
        final minutesToLimit = (maxTemp - currentTemp) / slopeCPerMin;
        if (minutesToLimit > 0 && minutesToLimit < 8) {
          final confidence = slopeSampleCount >= 90
              ? (60 + (5 - math.min(5, minutesToLimit)) * 6).round()
              : null;
          predictions.add(
            Prediction(
              kind: PredictionKind.overheatLikely,
              confidence: confidence?.clamp(0, 92).toInt(),
              severity: AnalysisSeverity.warning,
              valueArg: minutesToLimit.toStringAsFixed(1),
            ),
          );
        }
      }

      // 2) Approaching the configured limit while still rising.
      final distanceToLimit = maxTemp - currentTemp;
      if (distanceToLimit > 0 &&
          distanceToLimit <= 8 &&
          slopeCPerMin > 0) {
        predictions.add(
          Prediction(
            kind: PredictionKind.approachingLimit,
            confidence: 70,
            severity: AnalysisSeverity.warning,
            valueArg: distanceToLimit.toStringAsFixed(1),
          ),
        );
      }
    }

    // 3) Rising faster than usual (needs a meaningful baseline).
    if (slopeCPerMin != null && baseline.isUsable) {
      final baselineRise = math.max(baseline.avgRiseRateCPerMin.abs(), 0.1);
      if (slopeCPerMin > risingSlopeCPerMin &&
          slopeCPerMin > baselineRise * fastRiseRatio) {
        predictions.add(
          Prediction(
            kind: PredictionKind.tempRisingFasterThanUsual,
            confidence:
                (55 + 10 * math.log(1 + baseline.minutesObserved / 10))
                    .round()
                    .clamp(55, 88),
            severity: AnalysisSeverity.notice,
            valueArg: slopeCPerMin.toStringAsFixed(2),
          ),
        );
      }
    }

    // 4) Unusual voltage pattern (needs a meaningful baseline).
    if (baseline.isUsable && currentVoltage > 0) {
      final deviation = (currentVoltage - baseline.avgVoltage).abs();
      final deltaFlag =
          (voltageDelta90s ?? 0).abs() > abnormalVoltageDeltaV;
      if (deviation > 0.7 || deltaFlag) {
        predictions.add(
          Prediction(
            kind: PredictionKind.unusualVoltagePattern,
            confidence:
                (52 + 10 * math.log(1 + baseline.minutesObserved / 10))
                    .round()
                    .clamp(52, 85),
            severity: deltaFlag
                ? AnalysisSeverity.warning
                : AnalysisSeverity.notice,
            valueArg: (deltaFlag ? voltageDelta90s! : deviation)
                .abs()
                .toStringAsFixed(2),
          ),
        );
      }
    }

    // 5) Cooling-system attention pattern: repeated limit crossings or
    //    repeated long fan runs in this session's history.
    final stressEpisodes =
        stats.warningCrossings + stats.fanLongRunEpisodes;
    if (stressEpisodes >= 2) {
      predictions.add(
        Prediction(
          kind: PredictionKind.coolingSystemCheckSuggested,
          confidence: (45 + 10 * stressEpisodes).clamp(45, 85),
          severity: AnalysisSeverity.warning,
          valueArg: '$stressEpisodes',
        ),
      );
    }

    // 6) High temperature keeps happening at low speed (traffic/idle).
    final slow = stats.highTempSlowSpeedSamples;
    final fast = stats.highTempFastSpeedSamples;
    if (slow + fast >= 20 && slow >= fast * 2 && slow >= 12) {
      predictions.add(
        Prediction(
          kind: PredictionKind.heatRepeatedAtLowSpeed,
          confidence: (50 + slow / (slow + fast) * 40).round().clamp(50, 90),
          severity: AnalysisSeverity.notice,
        ),
      );
    }

    return predictions;
  }
}
