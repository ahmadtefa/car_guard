import 'package:car_guard/core/models/reading_sample.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingSample JSON', () {
    test('round-trips timestamp and telemetry values', () {
      final sample = ReadingSample(
        timestamp: DateTime.utc(2026, 10, 12, 20, 30),
        engineTemperature: 91.25,
        batteryVoltage: 12.64,
      );

      final restored = ReadingSample.fromJson(sample.toJson());

      expect(restored, isNotNull);
      expect(restored!.timestamp, sample.timestamp);
      expect(restored.engineTemperature, sample.engineTemperature);
      expect(restored.batteryVoltage, sample.batteryVoltage);
    });

    test('rejects malformed and non-finite readings', () {
      expect(ReadingSample.fromJson('not a map'), isNull);
      expect(
        ReadingSample.fromJson({
          'timestamp': 'not-a-date',
          'engineTemperature': 80,
          'batteryVoltage': 12,
        }),
        isNull,
      );
      expect(
        ReadingSample.fromJson({
          'timestamp': '2026-10-12T20:30:00Z',
          'engineTemperature': double.nan,
          'batteryVoltage': 12,
        }),
        isNull,
      );
    });
  });
}
