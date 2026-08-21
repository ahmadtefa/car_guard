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
    // Reject hopeless fixes: >30 m accuracy reads as noise, not motion.
    if (position.accuracy > 30 || position.accuracy <= 0) return;

    final last = _last;

    double deltaMeters = 0;
    double dtSeconds = 0;

    if (last != null) {
      dtSeconds =
          position.timestamp.difference(last.timestamp).inMilliseconds / 1000.0;

      if (dtSeconds > 0) {
        deltaMeters = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          position.latitude,
          position.longitude,
        );

        // Ignore sub-meter jitter and absurd jumps (teleport): a car cannot
        // cover >300 m between two consecutive fixes.
        if (deltaMeters < 1 || deltaMeters > 300) deltaMeters = 0;
      }
    }

    // Reported ground speed first — BUT many Android devices keep reporting
    // 0.0 (or -1) while moving, so when the reported speed looks dead yet
    // the ground delta over time clearly shows real motion, compute it
    // from position/time instead.
    double metersPerSecond = position.speed;

    final computed =
        dtSeconds > 0 ? deltaMeters / dtSeconds : 0.0;

    if (!metersPerSecond.isFinite ||
        metersPerSecond < 0 ||
        (metersPerSecond < 0.5 && computed > 1.0)) {
      metersPerSecond = computed;
    }

    double kmh = metersPerSecond * 3.6;

    _last = position;

    // GPS jitter under ~1.5 km/h reads as standing still.
    if (kmh < 1.5) kmh = 0;

    state = state.copyWith(
      speedKmh: kmh.clamp(0, 400),
      distanceKm: state.distanceKm + deltaMeters / 1000.0,
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
