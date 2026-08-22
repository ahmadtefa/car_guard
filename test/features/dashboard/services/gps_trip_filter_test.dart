import 'package:car_guard/features/dashboard/services/gps_trip_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _fix(
  double lat,
  double lng,
  int seconds, {
  double accuracy = 5,
  double speed = -1,
  double speedAccuracy = 0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: speedAccuracy,
  );
}

void main() {
  group('GpsTripFilter', () {
    test('parked jitter never accumulates distance and speed stays 0', () {
      final filter = GpsTripFilter();

      var totalKm = 0.0;
      var lastSpeed = 100.0;

      // Standing still with ~5 m of GPS noise for two minutes of fixes.
      for (var i = 0; i < 120; i++) {
        final reading = filter.addFix(
          _fix(
            30.0 + (i.isEven ? 0.00004 : -0.00003),
            31.0 + (i.isEven ? -0.00003 : 0.00004),
            i,
            accuracy: 8,
            speed: 0,
            speedAccuracy: 1,
          ),
        );

        if (reading != null) {
          totalKm += reading.stepKm;
          lastSpeed = reading.speedKmh;
        }
      }

      expect(totalKm, 0);
      expect(lastSpeed, 0);
    });

    test('steady 40 km/h drive: distance tracks the path, speed converges',
        () {
      final filter = GpsTripFilter();

      const steps = 90;
      const stepDeg = 0.0001; // ~11.1 m per step -> ~39.8 km/h at 1 fix/s

      var totalKm = 0.0;
      var lastSpeed = 0.0;

      for (var i = 0; i < steps; i++) {
        final reading = filter.addFix(
          _fix(30.0 + i * stepDeg, 31.0, i, accuracy: 5, speed: -1),
        );
        expect(reading, isNotNull);
        totalKm += reading!.stepKm;
        lastSpeed = reading.speedKmh;
      }

      // 89 real steps of ~11.06 m -> ~0.98 km. Allow generous ramp-up
      // tolerance but reject anything wildly off.
      expect(totalKm, greaterThan(0.75));
      expect(totalKm, lessThan(1.10));
      expect(lastSpeed, greaterThan(30));
      expect(lastSpeed, lessThan(48));
    });

    test('fixes with hopeless accuracy are rejected', () {
      final filter = GpsTripFilter();

      final good = filter.addFix(_fix(30.0, 31.0, 0, accuracy: 5));
      expect(good, isNotNull);

      final bad = filter.addFix(_fix(30.0005, 31.0005, 1, accuracy: 50));
      expect(bad, isNull);

      // The anchor did not move: the next good fix is compared against the
      // first one, and its (real) step stays small.
      final after = filter.addFix(_fix(30.0001, 31.0, 2, accuracy: 5));
      expect(after, isNotNull);
      expect(after!.stepKm, lessThan(0.1));
    });

    test('teleport fix is rejected and not accumulated', () {
      final filter = GpsTripFilter();

      var totalKm = 0.0;

      for (var i = 0; i < 10; i++) {
        totalKm += filter.addFix(
              _fix(30.0 + i * 0.0001, 31.0, i, accuracy: 5, speed: -1),
            )!.stepKm;
      }

      // Sudden 5 km jump in one second — physically impossible in a car.
      final teleport = filter.addFix(_fix(30.05, 31.0, 10, accuracy: 5));
      expect(teleport, isNull);

      // Normal motion resumes from the trusted anchor.
      for (var i = 10; i < 20; i++) {
        totalKm += filter.addFix(
              _fix(30.0 + i * 0.0001, 31.0, i, accuracy: 5, speed: -1),
            )!.stepKm;
      }

      // ~19 real steps of ~11 m: definitely below 0.5 km, never 5 km.
      expect(totalKm, lessThan(0.5));
    });
  });
}
