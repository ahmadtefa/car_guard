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

  group('voltageDeltaMagnitude', () {
    test('keeps a positive delta positive', () {
      expect(voltageDeltaMagnitude(0.42), 0.42);
    });

    test('maps a negative internal delta to its absolute value', () {
      expect(voltageDeltaMagnitude(-0.42), 0.42);
    });

    test('keeps zero at zero (scale start)', () {
      expect(voltageDeltaMagnitude(0), 0);
    });

    test('does not turn null into a fake zero', () {
      expect(voltageDeltaMagnitude(null), isNull);
    });
  });
}
