import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/background_service.dart';
import '../services/gps_trip_filter.dart';

/// Live trip data collected from the phone GPS.
class TripState {
  const TripState({
    this.speedKmh = 0,
    this.distanceKm = 0,
    this.hasFix = false,
    this.available = true,
    this.denied = false,
  });

  /// GPS ground speed in km/h (filtered and smoothed).
  final double speedKmh;

  /// Accumulated trip distance in km, reset by the user.
  final double distanceKm;

  /// Whether we are currently receiving usable GPS fixes.
  final bool hasFix;

  /// False when location services are off entirely.
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
/// Every raw fix goes through [GpsTripFilter] (quality gates + Kalman
/// position filter), so the displayed speed is stable and the accumulated
/// distance ignores parked jitter. The odometer survives app restarts (it
/// is reloaded from SharedPreferences on boot); only [resetTrip] zeroes it.
class TripNotifier extends Notifier<TripState> {
  StreamSubscription<Position>? _sub;
  final GpsTripFilter _filter = GpsTripFilter();

  bool _backgroundServiceStarted = false;

  /// The saved odometer is loaded only once per session — later [start]
  /// calls (permission re-grant, manual restart) must not rewind the live
  /// counter to whatever happens to be on disk.
  bool _restored = false;

  /// Last time the values were written to SharedPreferences — the disk is
  /// not hit more than once every two seconds for unchanged distances.
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  TripState build() {
    ref.onDispose(() => _sub?.cancel());
    // Fire and forget: restore the saved odometer first, then the GPS
    // stream populates the state asynchronously.
    Future<void>.microtask(() async {
      await _restoreDistance();
      await start();
    });
    return const TripState();
  }

  /// Brings back the distance saved by [_persist], so closing and reopening
  /// the app never wipes the odometer — only [resetTrip] zeroes it.
  Future<void> _restoreDistance() async {
    if (_restored) {
      return;
    }
    _restored = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('trip_distance_km');

      if (saved != null && saved > 0 && state.distanceKm == 0) {
        state = state.copyWith(distanceKm: saved);
      }
    } catch (_) {
      // Best effort: a failed read must not block live tracking.
    }
  }

  /// (Re)starts the GPS stream. Safe to call repeatedly. Never throws:
  /// platforms without a location plugin (tests, desktop) simply report
  /// the tracker as unavailable.
  Future<void> start() async {
    _sub?.cancel();
    _sub = null;
    _filter.reset();

    final LocationSettings settings;

    try {
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

      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    } catch (error) {
      debugPrint('TRIP TRACKER UNAVAILABLE: $error');
      state = state.copyWith(available: false, hasFix: false);
      return;
    }

    state = state.copyWith(available: true, denied: false);

    // Keep fixes flowing while the app is in the background: run the keep
    // alive foreground service, which also acquires the location-capable
    // service type as soon as the permission is granted.
    _ensureBackgroundService();

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onFix,
      onError: (_) {
        state = state.copyWith(hasFix: false);
      },
    );
  }

  void _onFix(Position position) {
    final reading = _filter.addFix(position);

    if (reading == null) {
      // Rejected as noise; keep showing the last trustworthy reading.
      return;
    }

    state = state.copyWith(
      speedKmh: reading.speedKmh,
      distanceKm: state.distanceKm + reading.stepKm,
      hasFix: true,
    );

    unawaited(_persist(distanceChanged: reading.stepKm > 0));
  }

  /// Zeroes the trip distance; speed keeps streaming.
  void resetTrip() {
    _filter.reset();
    state = state.copyWith(distanceKm: 0);
    unawaited(_persist(distanceChanged: true));
  }

  void _ensureBackgroundService() {
    if (_backgroundServiceStarted) {
      return;
    }
    _backgroundServiceStarted = true;
    unawaited(ref.read(backgroundConnectionServiceProvider).start());
  }

  /// Persists the values under the shared keys (`speed_kmh`,
  /// `trip_distance_km`) so car-screen integrations can read them without
  /// waiting for the app UI — and so [_restoreDistance] brings the odometer
  /// back after the app is closed and reopened. Writes are throttled
  /// unless the distance moved.
  Future<void> _persist({bool distanceChanged = false}) async {
    final now = DateTime.now();
    final due = distanceChanged ||
        now.difference(_lastPersist) >= const Duration(seconds: 2);
    if (!due) {
      return;
    }

    _lastPersist = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('speed_kmh', state.speedKmh);
      await prefs.setDouble('trip_distance_km', state.distanceKm);
    } catch (_) {
      // A failed write must never break live readings; the next accepted
      // fix simply tries again.
    }
  }
}

final tripProvider = NotifierProvider<TripNotifier, TripState>(
  TripNotifier.new,
);
