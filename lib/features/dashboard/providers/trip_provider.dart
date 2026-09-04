import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/background_service.dart';
import '../../license/providers/license_provider.dart';
import '../../settings/providers/settings_provider.dart';
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

  /// Watches location-service toggles so the tracker (re)starts when GPS
  /// is switched on after the app was launched.
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  /// Fires when no accepted fix arrived for [_gpsSilenceTimeout] — marks
  /// the feed stale instead of showing the last speed forever. Never
  /// touches the odometer value.
  Timer? _gpsWatchdog;

  /// How long the GPS may stay silent before the display stops trusting
  /// the last reading.
  static const Duration _gpsSilenceTimeout = Duration(seconds: 6);

  bool _backgroundServiceStarted = false;

  /// The saved odometer is loaded only once per authorized session — later
  /// [start] calls (permission re-grant, manual restart) must not rewind the
  /// live counter to whatever happens to be on disk.
  bool _restored = false;

  /// Real GPS/trip data is also treated as protected app data. Demo mode is
  /// allowed to use the existing phone-side trip feature; a normal device
  /// needs a fresh ACTIVE report from the ESP8266.
  bool _dataAccessAllowed = false;

  /// Last time the values were written to SharedPreferences — the disk is
  /// not hit more than once every two seconds for unchanged distances.
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  TripState build() {
    final settingsReady = ref.watch(
      settingsProvider.select((value) => value.value != null),
    );
    final demoEnabled = ref.watch(
      settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
    );
    final licenseAuthorized = ref.watch(licenseAuthorizationProvider);
    final allowed = settingsReady && (demoEnabled || licenseAuthorized);
    final wasAllowed = _dataAccessAllowed;
    _dataAccessAllowed = allowed;

    if (!allowed && wasAllowed) {
      _disableTracking();
    } else if (allowed && !wasAllowed) {
      _watchLocationService();
    }

    ref.onDispose(() {
      _sub?.cancel();
      _gpsWatchdog?.cancel();
      _serviceStatusSub?.cancel();
    });

    // Fire and forget: restore the saved odometer only after access is
    // allowed, then let the GPS stream populate the state asynchronously.
    Future<void>.microtask(() async {
      if (!_dataAccessAllowed) return;
      await _restoreDistance();
      if (_dataAccessAllowed) await start();
    });

    return allowed ? const TripState() : _neutralState;
  }

  static const TripState _neutralState = TripState(
    available: false,
    hasFix: false,
  );

  /// Stops the phone-side feed and removes its last values whenever the
  /// license/settings gate closes. This prevents analysis and alerts from
  /// retaining a previously authorized GPS reading.
  void _disableTracking() {
    _sub?.cancel();
    _sub = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _serviceStatusSub?.cancel();
    _serviceStatusSub = null;
    _filter.reset();
    _restored = false;
    _backgroundServiceStarted = false;
    unawaited(ref.read(backgroundConnectionServiceProvider).stop());
  }

  /// Subscribes once to location-service toggles, so enabling GPS after
  /// launch restarts the tracker instead of leaving the cards dead until
  /// the next app start.
  void _watchLocationService() {
    if (_serviceStatusSub != null) {
      return;
    }

    try {
      _serviceStatusSub = Geolocator.getServiceStatusStream().listen(
        _onServiceStatus,
        onError: (Object error) {
          debugPrint('GPS SERVICE STATUS UNAVAILABLE: $error');
        },
      );
    } catch (_) {
      // Platform without the plugin (tests, desktop) — nothing to watch.
    }
  }

  void _onServiceStatus(ServiceStatus status) {
    if (!_dataAccessAllowed) return;

    if (status == ServiceStatus.enabled) {
      // Safe to call repeatedly: the old stream is replaced.
      unawaited(start());
    } else {
      _gpsWatchdog?.cancel();
      state = state.copyWith(available: false, hasFix: false);
    }
  }

  /// Brings back the distance saved by [_persist], so closing and reopening
  /// the app never wipes the odometer — only [resetTrip] zeroes it.
  Future<void> _restoreDistance() async {
    if (!_dataAccessAllowed || _restored) {
      return;
    }
    _restored = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_dataAccessAllowed) return;
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
    if (!_dataAccessAllowed) return;

    _sub?.cancel();
    _sub = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _filter.reset();

    final LocationSettings settings;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (_dataAccessAllowed) {
          state = state.copyWith(available: false, hasFix: false);
        }
        return;
      }

      if (!_dataAccessAllowed) return;

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (_dataAccessAllowed) {
          state = state.copyWith(denied: true, hasFix: false);
        }
        return;
      }

      if (!_dataAccessAllowed) return;

      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    } catch (error) {
      debugPrint('TRIP TRACKER UNAVAILABLE: $error');
      if (_dataAccessAllowed) {
        state = state.copyWith(available: false, hasFix: false);
      }
      return;
    }

    if (!_dataAccessAllowed) return;

    state = state.copyWith(available: true, denied: false);

    // Keep fixes flowing while the app is in the background: run the keep
    // alive foreground service, which also acquires the location-capable
    // service type as soon as the permission is granted.
    _ensureBackgroundService();

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onFix,
      onError: (_) {
        _gpsWatchdog?.cancel();
        if (_dataAccessAllowed) {
          state = state.copyWith(hasFix: false);
        }
      },
    );

    _armGpsWatchdog();
  }

  void _onFix(Position position) {
    if (!_dataAccessAllowed) return;

    final reading = _filter.addFix(position);

    if (reading == null) {
      // Rejected as noise; keep showing the last trustworthy reading.
      // The watchdog is deliberately NOT rearmed: if only garbage fixes
      // arrive, the feed must go stale instead of clinging to old data.
      return;
    }

    state = state.copyWith(
      speedKmh: reading.speedKmh,
      distanceKm: state.distanceKm + reading.stepKm,
      hasFix: true,
    );

    _armGpsWatchdog();

    unawaited(_persist(distanceChanged: reading.stepKm > 0));
  }

  /// Rearms the stale-feed watchdog on every accepted fix. When GPS goes
  /// silent (tunnel, signal loss, a throttled stream) the cards switch to
  /// "no fix" instead of clinging to a frozen speed — the odometer value
  /// itself is never touched.
  void _armGpsWatchdog() {
    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer(_gpsSilenceTimeout, () {
      if (_dataAccessAllowed) {
        state = state.copyWith(hasFix: false);
      }
    });
  }

  /// Zeroes the trip distance; speed keeps streaming.
  void resetTrip() {
    if (!_dataAccessAllowed) return;

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
    if (!_dataAccessAllowed) return;

    final now = DateTime.now();
    final due = distanceChanged ||
        now.difference(_lastPersist) >= const Duration(seconds: 2);
    if (!due) {
      return;
    }

    _lastPersist = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_dataAccessAllowed) return;
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
