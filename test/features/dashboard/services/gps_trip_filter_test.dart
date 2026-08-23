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

/// Metres per degree of latitude at 30°N — matches what the filter's
/// WGS84 series computes for the scenarios below.
const double _mPerDeg = 110852.46;

/// Generates a coherent drive: every fix advances speed-consistent metres
/// and exactly one second, so positions always agree with the reported
/// speed (like a real drive, unlike teleporting between points).
class _Walker {
  double _meters = 0;
  int _seconds = -1;

  /// One fix one second later, having covered [kmh]-consistent metres.
  Position fix(
    double kmh, {
    bool trustedSpeed = true,
    double accuracy = 5,
  }) {
    _meters += kmh / 3.6;
    _seconds += 1;
    return _fix(
      30.0 + _meters / _mPerDeg,
      31.0,
      _seconds,
      accuracy: accuracy,
      speed: trustedSpeed ? kmh / 3.6 : -1,
      speedAccuracy: trustedSpeed ? 1 : 0,
    );
  }

  /// Places a fix [secondsAhead] later and [metersAhead] away from the
  /// origin without filling in the in-between — a GPS silence gap.
  Position jump({required int secondsAhead, required double metersAhead}) {
    _seconds += secondsAhead;
    _meters = metersAhead;
    return _fix(
      30.0 + _meters / _mPerDeg,
      31.0,
      _seconds,
      accuracy: 5,
      speed: -1,
    );
  }
}

void main() {
  group('GpsTripFilter — drift protection', () {
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

    test('random drift walk while parked accumulates exactly zero', () {
      final filter = GpsTripFilter();

      var totalKm = 0.0;
      var lastSpeed = 9.0;

      // Deterministic pseudo-random wiggle of up to ~2.5 m per axis.
      var seed = 42;
      double rnd() {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed / 0x7fffffff - 0.5;
      }

      var lat = 30.0;
      var lng = 31.0;

      for (var i = 0; i < 90; i++) {
        lat += rnd() * 5 / _mPerDeg;
        lng += rnd() * 5 / 96493.3;

        final reading = filter.addFix(
          _fix(lat, lng, i, accuracy: 6, speed: 0, speedAccuracy: 0.8),
        );

        if (reading != null) {
          totalKm += reading.stepKm;
          lastSpeed = reading.speedKmh;
        }
      }

      expect(totalKm, 0);
      expect(lastSpeed, 0);
    });
  });

  group('GpsTripFilter — speed response', () {
    test('departure counts from the first moving fix, speed reacts fast',
        () {
      final filter = GpsTripFilter();
      final walker = _Walker();

      final parked = filter.addFix(walker.fix(0))!;
      expect(parked.stepKm, 0);
      expect(parked.speedKmh, 0);

      // The first real step counts immediately — no waiting for the
      // display smoothing to climb out of the stop band.
      final firstMove = filter.addFix(walker.fix(8))!;
      expect(firstMove.stepKm, greaterThan(0.0005));
      expect(firstMove.speedKmh, greaterThan(5));
      expect(firstMove.speedKmh, lessThan(9));

      final mid = filter.addFix(walker.fix(15))!;
      expect(mid.stepKm, greaterThan(0.001));
      expect(mid.speedKmh, greaterThan(11));

      final fast = filter.addFix(walker.fix(30))!;
      expect(fast.stepKm, greaterThan(0.002));
      expect(fast.speedKmh, greaterThan(24));
    });

    test('acceleration 10→30→50→80 follows within a couple of fixes', () {
      final filter = GpsTripFilter();
      final walker = _Walker();

      for (var i = 0; i < 3; i++) {
        filter.addFix(walker.fix(10));
      }

      // One fix after the jump to 30 the display is already nearly there.
      final at30 = filter.addFix(walker.fix(30))!;
      expect(at30.speedKmh, greaterThan(24));
      expect(at30.speedKmh, lessThan(32));

      filter.addFix(walker.fix(30));
      final settled30 = filter.addFix(walker.fix(30))!;
      expect(settled30.speedKmh, greaterThan(27));
      expect(settled30.speedKmh, lessThan(32));

      final at50 = filter.addFix(walker.fix(50))!;
      expect(at50.speedKmh, greaterThan(42));
      expect(at50.speedKmh, lessThan(53));

      filter.addFix(walker.fix(50));
      filter.addFix(walker.fix(50));

      final at80 = filter.addFix(walker.fix(80))!;
      expect(at80.speedKmh, greaterThan(70));
      expect(at80.speedKmh, lessThan(83));

      filter.addFix(walker.fix(80));
      final settled80 = filter.addFix(walker.fix(80))!;
      expect(settled80.speedKmh, greaterThan(74));
      expect(settled80.speedKmh, lessThan(84));
    });

    test('braking 80→50→20→0 releases fast and never lingers', () {
      final filter = GpsTripFilter();
      final walker = _Walker();

      for (var i = 0; i < 3; i++) {
        filter.addFix(walker.fix(80));
      }

      // One fix after dropping to 50 the display is already near it —
      // it must not hang at 80 for seconds.
      final at50 = filter.addFix(walker.fix(50))!;
      expect(at50.speedKmh, greaterThan(46));
      expect(at50.speedKmh, lessThan(56));

      filter.addFix(walker.fix(50));
      filter.addFix(walker.fix(50));

      final at20 = filter.addFix(walker.fix(20))!;
      expect(at20.speedKmh, greaterThan(17));
      expect(at20.speedKmh, lessThan(26));

      filter.addFix(walker.fix(20));
      filter.addFix(walker.fix(20));

      final firstStop = filter.addFix(walker.fix(0))!;
      expect(firstStop.speedKmh, lessThan(4));

      final secondStop = filter.addFix(walker.fix(0))!;
      expect(secondStop.speedKmh, 0);

      final thirdStop = filter.addFix(walker.fix(0))!;
      expect(thirdStop.speedKmh, 0);
      expect(thirdStop.stepKm, 0);
    });

    test('hard brake to a standstill shows no phantom speed or distance',
        () {
      final filter = GpsTripFilter();
      final walker = _Walker();

      for (var i = 0; i < 4; i++) {
        filter.addFix(walker.fix(80));
      }

      // The Kalman estimate still walks out its lag after the car stops;
      // the raw-track witness must keep that from faking motion.
      final firstStop = filter.addFix(walker.fix(0))!;
      expect(firstStop.speedKmh, lessThan(10));
      expect(firstStop.stepKm, 0);

      final secondStop = filter.addFix(walker.fix(0))!;
      expect(secondStop.speedKmh, 0);
      expect(secondStop.stepKm, 0);

      final thirdStop = filter.addFix(walker.fix(0))!;
      expect(thirdStop.speedKmh, 0);
      expect(thirdStop.stepKm, 0);
    });

    test('small wobble around a steady speed stays stable', () {
      final filter = GpsTripFilter();
      final walker = _Walker();

      final speeds = [50.0, 51.5, 48.5, 50.0, 51.5, 48.5, 50.0];
      double? previous;

      for (final kmh in speeds) {
        final reading = filter.addFix(walker.fix(kmh))!;
        expect(reading.speedKmh, greaterThan(48));
        expect(reading.speedKmh, lessThan(52));
        // No jagged jumps: the slow EMA factor absorbs ±1.5 km/h noise.
        if (previous != null) {
          expect((reading.speedKmh - previous).abs(), lessThan(2));
        }
        previous = reading.speedKmh;
      }
    });
  });

  group('GpsTripFilter — distance accuracy', () {
    test('steady 40 km/h drive: distance tracks the path, speed converges',
        () {
      final filter = GpsTripFilter();

      const steps = 90;
      const stepDeg = 0.0001; // ~11.1 m per step -> ~39.9 km/h at 1 fix/s

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

      // 89 real steps of ~11.09 m -> ~0.99 km. Allow generous ramp-up
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

    test('a long GPS gap re-anchors and never counts the jump', () {
      final filter = GpsTripFilter();
      final walker = _Walker();

      var totalKm = 0.0;
      for (var i = 0; i < 5; i++) {
        totalKm += filter.addFix(walker.fix(40, trustedSpeed: false))!.stepKm;
      }

      final beforeGap = totalKm;
      expect(beforeGap, greaterThan(0.01));

      // 30 seconds of GPS silence while the car kept driving (~333 m on).
      final gapReading = filter.addFix(
        walker.jump(secondsAhead: 30, metersAhead: 388.9),
      )!;

      // Re-anchor: the whole gap is added as nothing, not as a teleport.
      expect(gapReading.stepKm, 0);
      expect(totalKm, beforeGap);

      // The drive after the gap counts again within a few fixes.
      for (var i = 0; i < 3; i++) {
        totalKm += filter.addFix(walker.fix(40, trustedSpeed: false))!.stepKm;
      }

      expect(totalKm, greaterThan(beforeGap));
      expect(totalKm, lessThan(0.08));
    });

    test('reset() re-anchors: the next fix starts a fresh track', () {
      final filter = GpsTripFilter();
      final walker = _Walker();

      var totalKm = 0.0;
      for (var i = 0; i < 5; i++) {
        totalKm += filter.addFix(walker.fix(40, trustedSpeed: false))!.stepKm;
      }
      expect(totalKm, greaterThan(0.005));

      filter.reset();

      final fresh = filter.addFix(walker.fix(40, trustedSpeed: false))!;
      expect(fresh.stepKm, 0);
    });
  });
}
