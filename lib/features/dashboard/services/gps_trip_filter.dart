import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// One accepted measurement produced by [GpsTripFilter].
class TripReading {
  const TripReading({required this.speedKmh, required this.stepKm});

  /// Smoothed ground speed in km/h.
  final double speedKmh;

  /// Filtered distance covered since the previous accepted fix, in km.
  final double stepKm;
}

/// Turns noisy raw GPS fixes into a trustworthy speed and distance stream.
///
/// Feeding raw fixes straight to the dashboard makes the speed jump around
/// and lets GPS jitter inflate the trip distance while parked. Here every
/// fix passes through quality gates and a small Kalman filter over the
/// position, and distance accumulates from the *filtered* positions only.
class GpsTripFilter {
  /// Fixes with worse horizontal accuracy than this are pure noise.
  static const double maxAccuracyM = 20;

  /// Sensor-reported speed is trusted when its own accuracy is unknown (0)
  /// or at least this good; otherwise speed comes from the filtered track.
  static const double maxSpeedAccuracyMs = 2.5;

  /// A "dead" sensor speed (0.0 while actually driving) is overridden by
  /// the filtered track only once it shows at least this much motion
  /// sustained across [overrideStreakFixes] fixes in a row — on BOTH the
  /// filtered track and the raw fixes (the raw check also stops the
  /// Kalman catch-up after hard braking from faking speed at a standstill).
  static const double deadSensorOverrideMs = 2.8;

  /// How many fixes in a row must beat [deadSensorOverrideMs] before a
  /// silent/untrusted sensor is overruled by the filtered track. A single
  /// fix can be one jitter jump; sustained motion cannot.
  static const int overrideStreakFixes = 2;

  /// Physics guard: jumps implying more than this are rejected.
  static const double maxPlausibleKmh = 250;

  /// Below this speed everything reads as "standing still" — this is what
  /// stops parked GPS jitter from accumulating phantom distance.
  static const double stopBandKmh = 1.5;

  /// Filtered steps smaller than this are round-off, not motion.
  static const double minStepM = 0.7;

  /// Kalman process noise (m²/s added to the variance per second): how fast
  /// we expect the true position to drift between fixes. Higher tracks
  /// faster but noisier; lower is smoother but laggier.
  static const double processNoiseM2PerSecond = 3.0;

  /// After a gap this long the old track is meaningless; re-anchor.
  static const double maxGapSeconds = 15;

  /// Display smoothing — adaptive instead of one fixed EMA factor: a fast
  /// attack/release on clear changes and a gentle factor for small wobble,
  /// so noise stays invisible while the response feels near-real-time.
  ///
  /// At the typical ~1 fix/s cadence, [_smoothingFastUp]/
  /// [_smoothingFastDown] cover ~90% of a step change within one or two
  /// fixes; [_smoothingSlow] keeps a steady reading from flickering.
  static const double _smoothingSlow = 0.35;
  static const double _smoothingFastUp = 0.85;
  static const double _smoothingFastDown = 0.9;

  /// A one-fix change of at least this size counts as "clear" and is
  /// followed with the fast factors above instead of the slow one.
  static const double _fastChangeKmh = 5;

  // -- Local equirectangular projection around the first fix --------------

  double _originLat = 0;
  double _originLng = 0;
  double _mPerDegLat = 110574;
  double _mPerDegLng = 111320;

  // -- Kalman state ---------------------------------------------------------

  double _xMeters = 0;
  double _yMeters = 0;
  double _varianceM2 = -1; // < 0 means "no anchor yet"

  Position? _lastFix;
  double _smoothedSpeedKmh = 0;

  /// Fixes in a row where the filtered track moved faster than
  /// [deadSensorOverrideMs] while the sensor stayed silent or untrusted.
  int _derivedMotionStreak = 0;

  /// Clears the filter (e.g. when the stream restarts or the trip resets).
  void reset() {
    _varianceM2 = -1;
    _lastFix = null;
    _smoothedSpeedKmh = 0;
    _derivedMotionStreak = 0;
  }

  /// Feeds one raw GPS fix. Returns `null` when the fix is rejected as
  /// noise; otherwise a filtered [TripReading] for this instant.
  TripReading? addFix(Position position) {
    // 1) Quality gate: hopeless accuracy reads as noise, not motion.
    if (position.accuracy <= 0 || position.accuracy > maxAccuracyM) {
      return null;
    }

    final lastFix = _lastFix;
    final dtSeconds = lastFix == null
        ? 0.0
        : position.timestamp.difference(lastFix.timestamp).inMilliseconds /
            1000.0;

    // Out-of-order fix (should not happen, but never feed one in).
    if (lastFix != null && dtSeconds <= 0) {
      return null;
    }

    final projected = _project(position.latitude, position.longitude);

    // Raw displacement since the previous fix — the teleport gate below
    // uses it, and section 5 reuses it as the "raw track" witness for the
    // motion-sustain check.
    var jumpM = 0.0;

    // 2) Teleport gate: compare the raw jump against what physics allows.
    if (lastFix != null && dtSeconds > 0 && dtSeconds <= maxGapSeconds) {
      final lastProjected = _project(lastFix.latitude, lastFix.longitude);
      jumpM = _distance(projected, lastProjected);
      final maxJumpM = (maxPlausibleKmh / 3.6) * dtSeconds +
          lastFix.accuracy +
          position.accuracy +
          10;

      if (jumpM > maxJumpM) {
        // Reject the bogus fix entirely and keep the trustworthy anchor.
        return null;
      }
    }

    // 3) (Re)anchor after a long gap or on the very first fix: the old
    //    track says nothing about where we are now.
    if (_varianceM2 < 0 || dtSeconds > maxGapSeconds) {
      _anchor(position);
      _lastFix = position;
      return TripReading(
        speedKmh: _smoothSpeed(_sensorSpeedMs(position), snap: true),
        stepKm: 0,
      );
    }

    // 4) Kalman update on the position.
    _varianceM2 += dtSeconds * processNoiseM2PerSecond;

    final accuracyM2 = position.accuracy * position.accuracy;
    final gain = _varianceM2 / (_varianceM2 + accuracyM2);

    final prevX = _xMeters;
    final prevY = _yMeters;

    _xMeters += gain * (projected.$1 - _xMeters);
    _yMeters += gain * (projected.$2 - _yMeters);
    _varianceM2 = (1 - gain) * _varianceM2;

    // 5) Speed: a trustworthy Doppler reading wins whenever it reports
    //    real motion. A silent (~0) or untrusted sensor falls back to the
    //    filtered track — but only once motion sustains across
    //    [overrideStreakFixes] fixes in a row on BOTH the filtered track
    //    and the raw fixes, so parked jitter (and the Kalman catch-up
    //    right after hard braking) can never fake a reading.
    final filteredStepM = _distance((_xMeters, _yMeters), (prevX, prevY));
    final derivedMs = dtSeconds > 0 ? filteredStepM / dtSeconds : 0.0;
    final rawDerivedMs = dtSeconds > 0 ? jumpM / dtSeconds : 0.0;

    final sensorMs = _sensorSpeedMs(position);
    final double metersPerSecond;

    if (sensorMs >= 0.5) {
      metersPerSecond = sensorMs;
      _derivedMotionStreak = 0;
    } else {
      if (derivedMs > deadSensorOverrideMs &&
          rawDerivedMs > deadSensorOverrideMs) {
        _derivedMotionStreak++;
      } else {
        _derivedMotionStreak = 0;
      }

      metersPerSecond =
          _derivedMotionStreak >= overrideStreakFixes ? derivedMs : 0.0;
    }

    final speedKmh = _smoothSpeed(metersPerSecond);

    // 6) Distance: gated by the *instantaneous* motion speed (before the
    //    display smoothing), so the first metres of every departure count
    //    immediately instead of waiting for the EMA to climb. While truly
    //    parked the motion speed is exactly 0, so drift still adds
    //    nothing.
    final motionKmh = metersPerSecond * 3.6;

    double stepM = 0;
    if (motionKmh >= stopBandKmh && filteredStepM >= minStepM) {
      final plausibleM = (maxPlausibleKmh / 3.6) * dtSeconds;
      stepM = math.min(filteredStepM, plausibleM);
    }

    _lastFix = position;

    return TripReading(speedKmh: speedKmh, stepKm: stepM / 1000.0);
  }

  /// Sensor speed in m/s, or -1 when the reading cannot be trusted.
  double _sensorSpeedMs(Position position) {
    final speed = position.speed;
    if (!speed.isFinite || speed < 0) {
      return -1;
    }

    // 0 means "accuracy unknown" on Android, which is fine to trust.
    final accuracy = position.speedAccuracy;
    if (accuracy > maxSpeedAccuracyMs) {
      return -1;
    }

    return speed;
  }

  /// Applies the dead-band and an adaptive EMA: clear changes (|delta| >=
  /// [_fastChangeKmh]) are followed fast — braking even faster than
  /// acceleration — while small wobble keeps the gentle factor so the
  /// number stays steady. [snap] jumps straight to the value (used for
  /// the first fix and after long gaps).
  double _smoothSpeed(double metersPerSecond, {bool snap = false}) {
    double kmh = (metersPerSecond * 3.6).clamp(0, maxPlausibleKmh);

    if (kmh < stopBandKmh) {
      kmh = 0;
    }

    if (snap) {
      _smoothedSpeedKmh = kmh;
    } else {
      final deltaKmh = kmh - _smoothedSpeedKmh;
      final alpha = deltaKmh.abs() >= _fastChangeKmh
          ? (deltaKmh > 0 ? _smoothingFastUp : _smoothingFastDown)
          : _smoothingSlow;
      _smoothedSpeedKmh += alpha * deltaKmh;
    }

    if (_smoothedSpeedKmh < stopBandKmh) {
      return 0;
    }

    return _smoothedSpeedKmh;
  }

  void _anchor(Position position) {
    _originLat = position.latitude;
    _originLng = position.longitude;

    // WGS84 metres-per-degree series evaluated at the anchor latitude —
    // a single global constant mismeasures latitude motion by ~0.25% at
    // Egyptian latitudes (more elsewhere), which directly inflates or
    // shrinks the odometer.
    final latRad = _originLat * math.pi / 180.0;
    _mPerDegLat = 111132.954 -
        559.822 * math.cos(2 * latRad) +
        1.175 * math.cos(4 * latRad);
    _mPerDegLng =
        111412.84 * math.cos(latRad) - 93.5 * math.cos(3 * latRad);

    _xMeters = 0;
    _yMeters = 0;
    _varianceM2 = position.accuracy * position.accuracy;
  }

  /// Local equirectangular projection: accurate enough for trip distances
  /// (well below 1% error for any realistic drive).
  (double, double) _project(double latitude, double longitude) {
    if (_varianceM2 < 0) {
      return (0, 0); // replaced when the anchor is set on this same fix
    }

    return (
      (longitude - _originLng) * _mPerDegLng,
      (latitude - _originLat) * _mPerDegLat,
    );
  }

  double _distance((double, double) a, (double, double) b) {
    final dx = a.$1 - b.$1;
    final dy = a.$2 - b.$2;
    return math.sqrt(dx * dx + dy * dy);
  }
}
