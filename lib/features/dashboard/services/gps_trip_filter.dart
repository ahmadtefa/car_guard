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
  /// the filtered track only once it shows at least this much sustained
  /// motion — a weaker gate would let parked GPS jitter fake movement.
  static const double deadSensorOverrideMs = 2.8;

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

  /// How quickly the displayed speed follows the estimate (EMA factor).
  static const double _speedSmoothing = 0.45;

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

  /// Clears the filter (e.g. when the stream restarts or the trip resets).
  void reset() {
    _varianceM2 = -1;
    _lastFix = null;
    _smoothedSpeedKmh = 0;
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

    // 2) Teleport gate: compare the raw jump against what physics allows.
    if (lastFix != null && dtSeconds > 0 && dtSeconds <= maxGapSeconds) {
      final lastProjected = _project(lastFix.latitude, lastFix.longitude);
      final jumpM = _distance(projected, lastProjected);
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

    // 5) Speed: prefer the GNSS Doppler speed when it is trustworthy,
    //    otherwise derive it from the filtered track.
    double metersPerSecond = _sensorSpeedMs(position);

    final filteredStepM = _distance((_xMeters, _yMeters), (prevX, prevY));
    final derivedMs = dtSeconds > 0 ? filteredStepM / dtSeconds : 0.0;

    if (metersPerSecond < 0) {
      metersPerSecond = derivedMs;
    } else if (metersPerSecond < 0.5 &&
        derivedMs > deadSensorOverrideMs) {
      // Some devices keep reporting 0 while moving; trust the filtered
      // track then, but only for clearly real motion.
      metersPerSecond = derivedMs;
    }

    final speedKmh = _smoothSpeed(metersPerSecond);

    // 6) Distance: no accumulation while inside the stop band — a parked
    //    car keeps exactly the same trip value instead of creeping up.
    double stepM = 0;
    if (speedKmh >= stopBandKmh && filteredStepM >= minStepM) {
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

  /// Applies the dead-band and a short-memory EMA so the displayed number
  /// is stable without feeling laggy. [snap] jumps straight to the value
  /// (used for the first fix and after long gaps).
  double _smoothSpeed(double metersPerSecond, {bool snap = false}) {
    double kmh = (metersPerSecond * 3.6).clamp(0, maxPlausibleKmh);

    if (kmh < stopBandKmh) {
      kmh = 0;
    }

    if (snap) {
      _smoothedSpeedKmh = kmh;
    } else {
      _smoothedSpeedKmh += _speedSmoothing * (kmh - _smoothedSpeedKmh);
    }

    if (_smoothedSpeedKmh < stopBandKmh) {
      return 0;
    }

    return _smoothedSpeedKmh;
  }

  void _anchor(Position position) {
    _originLat = position.latitude;
    _originLng = position.longitude;
    _mPerDegLat = 110574;
    _mPerDegLng = 111320 * math.cos(_originLat * math.pi / 180.0);

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
