import 'package:car_guard/core/models/reading_sample.dart';
import 'package:car_guard/features/dashboard/providers/voltage_delta_provider.dart';
import 'package:flutter_test/flutter_test.dart';

ReadingSample _sample(DateTime time, double volt) => ReadingSample(
      timestamp: time,
      engineTemperature: 80,
      batteryVoltage: volt,
    );

void main() {
  final base = DateTime(2026, 1, 1, 10, 0, 0);

  group('computeVoltageDelta', () {
    test('returns null until two samples exist', () {
      expect(computeVoltageDelta(const []), isNull);
      expect(
        computeVoltageDelta([_sample(base, 12.0)]),
        isNull,
      );
    });

    test('measures the rise over the lookback window', () {
      final history = [
        _sample(base, 12.0),
        _sample(base.add(const Duration(seconds: 30)), 12.4),
        _sample(base.add(const Duration(seconds: 90)), 13.6),
      ];

      final delta = computeVoltageDelta(
        history,
        lookback: const Duration(seconds: 60),
      )!;

      // Oldest sample inside the 60s window is the 12.4 V one.
      expect(delta, closeTo(1.2, 0.0001));
    });

    test('falls back to the first sample when window covers everything', () {
      final history = [
        _sample(base, 12.2),
        _sample(base.add(const Duration(seconds: 10)), 12.1),
      ];

      expect(computeVoltageDelta(history), closeTo(-0.1, 0.0001));
    });

    test('handles negative (dropping) values', () {
      final history = [
        _sample(base, 13.8),
        _sample(base.add(const Duration(seconds: 30)), 13.0),
      ];

      expect(computeVoltageDelta(history), closeTo(-0.8, 0.0001));
    });
  });

  group('resolveVoltageDelta', () {
    test('prefers a valid module-reported value over the history fallback', () {
      final history = [
        _sample(base, 12.0),
        _sample(base.add(const Duration(seconds: 90)), 13.6),
      ];

      expect(
        resolveVoltageDelta(moduleDelta: 0.24, history: history),
        closeTo(0.24, 0.0001),
      );
    });

    test('keeps a legitimate module-reported zero as a real value', () {
      final history = [
        _sample(base, 12.0),
        _sample(base.add(const Duration(seconds: 90)), 13.6),
      ];

      expect(resolveVoltageDelta(moduleDelta: 0, history: history), 0);
    });

    test('uses the 90-second fallback when the module value is unavailable',
        () {
      final history = [
        _sample(base, 12.0),
        _sample(base.add(const Duration(seconds: 90)), 13.6),
      ];

      expect(
        resolveVoltageDelta(moduleDelta: null, history: history),
        closeTo(1.6, 0.0001),
      );
    });

    test('preserves null when neither source is available', () {
      expect(resolveVoltageDelta(moduleDelta: null, history: const []), isNull);
    });
  });
}
