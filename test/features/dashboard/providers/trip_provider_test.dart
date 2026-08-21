import 'package:car_guard/features/dashboard/providers/trip_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripState', () {
    test('copyWith keeps untouched fields', () {
      const base = TripState(speedKmh: 42, distanceKm: 3.5);

      final next = base.copyWith(speedKmh: 60);

      expect(next.speedKmh, 60);
      expect(next.distanceKm, 3.5);
      expect(next.available, isTrue);
      expect(next.denied, isFalse);
    });

    test('reset-style copyWith zeroes only the distance', () {
      const base = TripState(speedKmh: 80, distanceKm: 12.3, hasFix: true);

      final reset = base.copyWith(distanceKm: 0);

      expect(reset.distanceKm, 0);
      expect(reset.speedKmh, 80);
      expect(reset.hasFix, isTrue);
    });
  });
}
