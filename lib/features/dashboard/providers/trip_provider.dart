import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Live trip data collected from the phone GPS.
class TripState {
  const TripState({
    this.speedKmh = 0,
    this.distanceKm = 0,
    this.hasFix = false,
    this.available = true,
    this.denied = false,
  });

  /// GPS ground speed in km/h (already smoothed).
  final double speedKmh;

  /// Accumulated trip distance in km, reset by the user.
  final double distanceKm;

  /// Whether we are currently receiving usable GPS fixes.
  final bool hasFix;

  /// False when Location services are off entirely.
  final bool available;

  /// True when the user denied the location permission.
  final bool denied;

  TripState copyWith({
    double? speedKmh,
    double? distanceKm,
    bool? hasFix,
    bool? available,
    bool? denied,
  }) {
    return TripState(
      speedKmh: speedKmh ?? this.speedKmh,
      distanceKm: distanceKm ?? this.distanceKm,
      hasFix: hasFix ?? this.hasFix,
      available: available ?? this.available,
      denied: denied ?? this.denied,
    );
  }
}

/// Tracks GPS speed and trip distance for the dashboard cards.
///
/// Pure-additive distance logic: every fix contributes only the
/// filtered distance between consecutive positions, so GPS noise while
/// parked never inflates the trip. Call [resetTrip] to zero the counter.
class TripNotifier extends Notifier<TripState> {
  StreamSubscription<Position>? _sub;
  Position? _last;

  @override
  TripState build() {
    ref.onDispose(() => _sub?.cancel());
    // Fire and forget; the stream populates the state asynchronously.
    Future<void>.microtask(start);
    return const TripState();
  }

  /// (Re)starts the GPS stream. Safe to call repeatedly.
  Future<void> start() async {
    _sub?.cancel();
    _sub = null;
    _last = null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(available: false, hasFix: false);
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      state = state.copyWith(denied: true, hasFix: false);
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    state = state.copyWith(available: true, denied: false);

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onFix,
      onError: (_) {
        state = state.copyWith(hasFix: false);
      },
    );
  }

  void _onFix(Position position) {
    // Reject hopeless fixes: >25 m accuracy reads as noise, not motion.
    if (position.accuracy > 25 || position.accuracy <= 0) return;

    double deltaKm = 0;
    double speed = position.speed * 3.6; // m/s -> km/h

    final last = _last;

    if (last != null) {
      final dt = position.timestamp.difference(last.timestamp).inMilliseconds;
      final d = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );

      // Ignore sub-meter jitter and absurd jumps (teleport): a car cannot
      // cover >300 m between two consecutive fixes.
      if (d >= 1 && d < 300 && dt > 0) deltaKm = d / 1000.0;

      // Some devices report -1 speed; fall back to distance/time.
      if (speed < 0 && dt > 0) {
        speed = deltaKm * 3.6 * 1000 / dt;
      }
    }

    _last = position;

    // GPS speed jitter under ~1.5 km/h reads as standing still.
    if (speed < 1.5) speed = 0;

    state = state.copyWith(
      speedKmh: speed.clamp(0, 400),
      distanceKm: state.distanceKm + deltaKm,
      hasFix: true,
    );
  }

  /// Zeroes the trip distance; speed keeps streaming.
  void resetTrip() {
    _last = null;
    state = state.copyWith(distanceKm: 0);
  }
}

final tripProvider = NotifierProvider<TripNotifier, TripState>(
  TripNotifier.new,
);
