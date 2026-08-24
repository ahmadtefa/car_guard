import 'dart:math' as math;

import 'package:car_guard/core/models/reading_sample.dart';
import 'package:car_guard/features/analysis/models/analysis_models.dart';
import 'package:car_guard/features/analysis/services/analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure-unit coverage for the local analysis engine: slope maths, the
/// smart alert tracker (cooldown + escalation + clearing) and every
/// prediction gate. No device, no storage, no widget tree.
void main() {
  List<ReadingSample> samples({
    required int count,
    required Duration step,
    required double Function(int index) temp,
    double volt = 12.6,
    DateTime? end,
  }) {
    final last = end ?? DateTime(2026, 8, 24, 14, 30);
    final first = last.subtract(step * (count - 1));
    return [
      for (var i = 0; i < count; i++)
        ReadingSample(
          timestamp: first.add(step * i),
          engineTemperature: temp(i),
          batteryVoltage: volt,
        ),
    ];
  }

  group('computeTempSlopeCPerMin', () {
    test('returns null until at least 5 samples exist', () {
      final history = samples(
        count: 4,
        step: const Duration(seconds: 30),
        temp: (i) => 80.0,
      );
      expect(AnalysisEngine.computeTempSlopeCPerMin(history), isNull);
    });

    test('fits a steady +2°C/min rise correctly', () {
      // +1°C every 30 s for five minutes → exactly 2°C/min.
      final history = samples(
        count: 11,
        step: const Duration(seconds: 30),
        temp: (i) => 80.0 + i,
      );
      final slope = AnalysisEngine.computeTempSlopeCPerMin(history);
      expect(slope, isNotNull);
      expect(slope!, closeTo(2.0, 0.01));
    });

    test('flat readings report a ~zero slope', () {
      final history = samples(
        count: 10,
        step: const Duration(seconds: 30),
        temp: (_) => 90.0,
      );
      expect(AnalysisEngine.computeTempSlopeCPerMin(history), closeTo(0, 1e-6));
    });

    test('only the trailing window shapes the slope', () {
      // Eight minutes of steep rise, then flat for the last two minutes.
      final history = samples(
        count: 21,
        step: const Duration(seconds: 30),
        temp: (i) => i < 16 ? 60.0 + i : 76.0,
      );
      final slope = AnalysisEngine.computeTempSlopeCPerMin(history);
      expect(slope, isNotNull);
      expect(slope!.abs(), lessThan(0.3));
    });
  });

  group('SmartAlertTracker', () {
    final t0 = DateTime(2026, 8, 24, 14, 30);

    test('opens exactly one episode per kind and logs it once', () {
      final tracker = AnalysisEngine.SmartAlertTracker();

      final first = tracker.update(
        AnalysisAlertKind.engineTempHigh,
        condition: true,
        severity: AnalysisSeverity.danger,
        now: t0,
        readings: const {'temp': 97},
      );
      expect(first, AnalysisEngine.TrackerEvent.started);
      expect(tracker.active.length, 1);
      expect(tracker.active[AnalysisAlertKind.engineTempHigh]!.occurrences, 1);

      // Persisting within the cooldown never fires again — quiet refresh.
      final again = tracker.update(
        AnalysisAlertKind.engineTempHigh,
        condition: true,
        severity: AnalysisSeverity.danger,
        now: t0.add(const Duration(minutes: 3)),
        readings: const {'temp': 98},
      );
      expect(again, isNull);
      expect(
        tracker.active[AnalysisAlertKind.engineTempHigh]!.occurrences,
        1,
      );
      expect(
        tracker.active[AnalysisAlertKind.engineTempHigh]!.readings['temp'],
        98,
      );
    });

    test('escalates one tier after the cooldown while the problem persists',
        () {
      final tracker = AnalysisEngine.SmartAlertTracker();

      tracker.update(
        AnalysisAlertKind.coolantLow,
        condition: true,
        severity: AnalysisSeverity.warning,
        now: t0,
      );

      final escalated = tracker.update(
        AnalysisAlertKind.coolantLow,
        condition: true,
        severity: AnalysisSeverity.warning,
        now: t0.add(const Duration(minutes: 11)),
      );

      expect(escalated, AnalysisEngine.TrackerEvent.escalated);
      final alert = tracker.active[AnalysisAlertKind.coolantLow]!;
      expect(alert.severity, AnalysisSeverity.danger);
      expect(alert.occurrences, 2);
    });

    test('danger never escalates past danger', () {
      final tracker = AnalysisEngine.SmartAlertTracker();

      tracker.update(
        AnalysisAlertKind.engineTempHigh,
        condition: true,
        severity: AnalysisSeverity.danger,
        now: t0,
      );
      tracker.update(
        AnalysisAlertKind.engineTempHigh,
        condition: true,
        severity: AnalysisSeverity.danger,
        now: t0.add(const Duration(minutes: 11)),
      );

      expect(
        tracker.active[AnalysisAlertKind.engineTempHigh]!.severity,
        AnalysisSeverity.danger,
      );
    });

    test('clears only after the condition is gone for long enough', () {
      final tracker = AnalysisEngine.SmartAlertTracker();

      tracker.update(
        AnalysisAlertKind.batteryLow,
        condition: true,
        severity: AnalysisSeverity.warning,
        now: t0,
      );

      // 20 s of false: episode must survive (flicker guard).
      final flicker = tracker.update(
        AnalysisAlertKind.batteryLow,
        condition: false,
        severity: AnalysisSeverity.warning,
        now: t0.add(const Duration(seconds: 20)),
      );
      expect(flicker, isNull);
      expect(tracker.active.length, 1);

      // Fresh reading while in the grace window keeps the same episode.
      final resumed = tracker.update(
        AnalysisAlertKind.batteryLow,
        condition: true,
        severity: AnalysisSeverity.warning,
        now: t0.add(const Duration(seconds: 30)),
      );
      expect(resumed, isNull);
      expect(tracker.active[AnalysisAlertKind.batteryLow]!.occurrences, 1);

      // The condition goes false: the 45 s absence timer starts NOW, so
      // the episode still survives the first quiet reading.
      final gone = tracker.update(
        AnalysisAlertKind.batteryLow,
        condition: false,
        severity: AnalysisSeverity.warning,
        now: t0.add(const Duration(minutes: 2)),
      );
      expect(gone, isNull);
      expect(tracker.active.length, 1);

      // Still false 50 s later: episode closes.
      final cleared = tracker.update(
        AnalysisAlertKind.batteryLow,
        condition: false,
        severity: AnalysisSeverity.warning,
        now: t0.add(const Duration(minutes: 2, seconds: 50)),
      );
      expect(cleared, AnalysisEngine.TrackerEvent.cleared);
      expect(tracker.active.length, 0);

      // Next fire is a brand new episode (logged separately upstream).
      final restarted = tracker.update(
        AnalysisAlertKind.batteryLow,
        condition: true,
        severity: AnalysisSeverity.warning,
        now: t0.add(const Duration(minutes: 3)),
      );
      expect(restarted, AnalysisEngine.TrackerEvent.started);
      expect(tracker.active[AnalysisAlertKind.batteryLow]!.occurrences, 1);
    });

    test('activeAlerts lists the most severe episode first', () {
      final tracker = AnalysisEngine.SmartAlertTracker();

      tracker.update(
        AnalysisAlertKind.voltageUnstable,
        condition: true,
        severity: AnalysisSeverity.notice,
        now: t0,
      );
      tracker.update(
        AnalysisAlertKind.engineTempHigh,
        condition: true,
        severity: AnalysisSeverity.danger,
        now: t0,
      );

      final alerts = tracker.activeAlerts();
      expect(alerts.first.kind, AnalysisAlertKind.engineTempHigh);
      expect(alerts.last.kind, AnalysisAlertKind.voltageUnstable);
    });
  });

  group('buildPredictions', () {
    const usableBaseline = BaselineStats(
      avgTemp: 84,
      avgVoltage: 12.6,
      avgRiseRateCPerMin: 0.2,
      minutesObserved: 60,
      sessions: 12,
    );

    test('overheat soon: distance/slope pair gives an ETA + confidence', () {
      final predictions = AnalysisEngine.buildPredictions(
        currentTemp: 95,
        slopeCPerMin: 2.0, // 10°C below the limit, rising 2°C/min → 5 min
        maxTemp: 105,
        voltageDelta90s: 0.1,
        currentVoltage: 12.6,
        stats: const SessionStats(),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );

      final overheat = predictions.where(
        (p) => p.kind == PredictionKind.overheatLikely,
      );
      expect(overheat.length, 1);
      expect(overheat.first.confidence, 60);
      expect(overheat.first.valueArg, '5.0');
    });

    test('overheat ETA reports "insufficient data" with too few samples',
        () {
      final predictions = AnalysisEngine.buildPredictions(
        currentTemp: 95,
        slopeCPerMin: 2.0,
        maxTemp: 105,
        voltageDelta90s: 0.1,
        currentVoltage: 12.6,
        stats: const SessionStats(),
        baseline: usableBaseline,
        slopeSampleCount: 30,
      );

      final overheat = predictions.where(
        (p) => p.kind == PredictionKind.overheatLikely,
      );
      expect(overheat.length, 1);
      expect(overheat.first.confidence, isNull);
    });

    test('approaching the limit fires with its remaining distance', () {
      final predictions = AnalysisEngine.buildPredictions(
        currentTemp: 93,
        slopeCPerMin: 0.5, // ETA 14 min → overheat rule stays silent
        maxTemp: 100,
        voltageDelta90s: 0.1,
        currentVoltage: 12.6,
        stats: const SessionStats(),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );

      final approaching = predictions.where(
        (p) => p.kind == PredictionKind.approachingLimit,
      );
      expect(approaching.length, 1);
      expect(approaching.first.confidence, 70);
      expect(approaching.first.valueArg, '7.0');
    });

    test(
        'rising faster than usual needs a usable baseline and scales its '
        'confidence with observed minutes', () {
      final expected = (55 + 10 * math.log(1 + 60 / 10)).round();

      final predictions = AnalysisEngine.buildPredictions(
        currentTemp: 88,
        slopeCPerMin: 0.5, // > 0.25 and > 1.5 × baseline rise (0.2)
        maxTemp: 105,
        voltageDelta90s: 0.1,
        currentVoltage: 12.6,
        stats: const SessionStats(),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );

      final fast = predictions.where(
        (p) => p.kind == PredictionKind.tempRisingFasterThanUsual,
      );
      expect(fast.length, 1);
      expect(fast.first.confidence, expected);

      // Without a usable baseline the same readings stay silent.
      final noBaseline = AnalysisEngine.buildPredictions(
        currentTemp: 88,
        slopeCPerMin: 0.5,
        maxTemp: 105,
        voltageDelta90s: 0.1,
        currentVoltage: 12.6,
        stats: const SessionStats(),
        baseline: const BaselineStats(),
        slopeSampleCount: 100,
      );
      expect(
        noBaseline
            .where((p) => p.kind == PredictionKind.tempRisingFasterThanUsual),
        isEmpty,
      );
    });

    test('unusual voltage: deviation branch and delta branch', () {
      // Deviation from the usual average (|13.8 − 12.6| = 1.2 > 0.7).
      final deviated = AnalysisEngine.buildPredictions(
        currentTemp: 84,
        slopeCPerMin: 0,
        maxTemp: 105,
        voltageDelta90s: 0.2,
        currentVoltage: 13.8,
        stats: const SessionStats(),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );
      final byDeviation = deviated.where(
        (p) => p.kind == PredictionKind.unusualVoltagePattern,
      );
      expect(byDeviation.length, 1);
      expect(byDeviation.first.severity, AnalysisSeverity.notice);
      expect(
        byDeviation.first.confidence,
        (52 + 10 * math.log(1 + 60 / 10)).round(),
      );

      // Sharp 90-second swing (0.9 V > 0.8 V) with an average on point.
      final swung = AnalysisEngine.buildPredictions(
        currentTemp: 84,
        slopeCPerMin: 0,
        maxTemp: 105,
        voltageDelta90s: 0.9,
        currentVoltage: 12.6,
        stats: const SessionStats(),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );
      final byDelta = swung.where(
        (p) => p.kind == PredictionKind.unusualVoltagePattern,
      );
      expect(byDelta.length, 1);
      expect(byDelta.first.severity, AnalysisSeverity.warning);
    });

    test('cooling check suggestion needs at least two stress episodes', () {
      final oneEpisode = AnalysisEngine.buildPredictions(
        currentTemp: 84,
        slopeCPerMin: 0,
        maxTemp: 105,
        voltageDelta90s: 0,
        currentVoltage: 12.6,
        stats: const SessionStats(warningCrossings: 1),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );
      expect(
        oneEpisode.where(
          (p) => p.kind == PredictionKind.coolingSystemCheckSuggested,
        ),
        isEmpty,
      );

      final twoEpisodes = AnalysisEngine.buildPredictions(
        currentTemp: 84,
        slopeCPerMin: 0,
        maxTemp: 105,
        voltageDelta90s: 0,
        currentVoltage: 12.6,
        stats: const SessionStats(
          warningCrossings: 1,
          fanLongRunEpisodes: 1,
        ),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );
      final suggestion = twoEpisodes.where(
        (p) => p.kind == PredictionKind.coolingSystemCheckSuggested,
      );
      expect(suggestion.length, 1);
      expect(suggestion.first.confidence, 65);
    });

    test('traffic-jam heat correlation needs enough low-speed samples', () {
      final enough = AnalysisEngine.buildPredictions(
        currentTemp: 91,
        slopeCPerMin: 0,
        maxTemp: 105,
        voltageDelta90s: 0,
        currentVoltage: 12.6,
        stats: const SessionStats(
          highTempSlowSpeedSamples: 24,
          highTempFastSpeedSamples: 10,
        ),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );
      final correlation = enough.where(
        (p) => p.kind == PredictionKind.heatRepeatedAtLowSpeed,
      );
      expect(correlation.length, 1);
      expect(correlation.first.confidence, 78);

      final notEnough = AnalysisEngine.buildPredictions(
        currentTemp: 91,
        slopeCPerMin: 0,
        maxTemp: 105,
        voltageDelta90s: 0,
        currentVoltage: 12.6,
        stats: const SessionStats(
          highTempSlowSpeedSamples: 10,
          highTempFastSpeedSamples: 10,
        ),
        baseline: usableBaseline,
        slopeSampleCount: 100,
      );
      expect(
        notEnough.where((p) => p.kind == PredictionKind.heatRepeatedAtLowSpeed),
        isEmpty,
      );
    });

    test('calm readings with a calm baseline produce no predictions', () {
      final predictions = AnalysisEngine.buildPredictions(
        currentTemp: 84,
        slopeCPerMin: 0,
        maxTemp: 105,
        voltageDelta90s: 0.05,
        currentVoltage: 12.6,
        stats: const SessionStats(),
        baseline: usableBaseline,
        slopeSampleCount: 200,
      );
      expect(predictions, isEmpty);
    });
  });
}
