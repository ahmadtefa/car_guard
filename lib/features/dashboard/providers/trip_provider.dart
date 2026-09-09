import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/background_service.dart';
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

  /// The saved odometer is loaded once per notifier lifetime — later [start]
  /// calls (permission re-grant, manual restart) must not rewind the live
  /// counter to whatever happens to be on disk.
  bool _restored = false;

  /// The latest value read from storage. Restoration is independent from
  /// settings readiness; settings only gates operational GPS tracking.
  double? _restoredDistance;

  /// The single restoration operation for this notifier lifetime. Keeping the
  /// future separate from settings avoids cancelling a storage read when
  /// settings changes from loading to ready.
  Future<void>? _restoreOperation;
  bool _startQueued = false;

  /// True once persisted settings are ready. GPS/trip state is read-only and
  /// does not grant or bypass any protected module command.
  bool _dataAccessAllowed = false;

  /// Invalidates microtasks and async GPS/restore operations from an older
  /// provider build. Settings readiness is listened to without rebuilding this
  /// notifier, but an explicit provider rebuild must still invalidate work.
  int _lifecycleGeneration = 0;

  /// Invalidates an older GPS start when a service-status callback or another
  /// caller requests a restart before the previous permission flow completes.
  int _startGeneration = 0;

  /// Set before any dispose cleanup so callbacks and async continuations do
  /// not touch [state] or [ref] after Riverpod has torn the provider down.
  bool _disposed = false;

  /// The service instance is cached while the notifier is alive, allowing
  /// disposal to stop it without reading [ref] after the dispose callback.
  BackgroundConnectionService? _backgroundService;

  /// Last time the values were written to SharedPreferences — the disk is
  /// not hit more than once every two seconds for unchanged distances.
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  TripState build() {
    // A manual provider rebuild may reuse the notifier after onDispose
    // cleanup. It is live again for this build.
    _disposed = false;
    final generation = ++_lifecycleGeneration;

    ref.onDispose(() {
      _disposed = true;
      _dataAccessAllowed = false;
      _lifecycleGeneration++;
      _startGeneration++;

      _sub?.cancel();
      _sub = null;
      _gpsWatchdog?.cancel();
      _gpsWatchdog = null;
      _serviceStatusSub?.cancel();
      _serviceStatusSub = null;
      _filter.reset();
      _restored = false;
      _restoreOperation = null;
      _startQueued = false;
      _backgroundServiceStarted = false;
      _restoredDistance = null;
      _stopBackgroundService();
    });

    // Listen to settings without watching them. Readiness changes control GPS
    // access, but must not rebuild this notifier while restoration is pending.
    ref.listen(
      settingsProvider.select((value) => value.value != null),
      (previous, allowed) {
        if (!_isGenerationActive(generation)) return;
        _onSettingsReadinessChanged(allowed, generation);
      },
      fireImmediately: true,
    );

    // Start exactly one restoration operation for this notifier lifetime.
    // It is intentionally independent from settings readiness.
    _beginRestoration(generation);
    _scheduleStartAfterRestoration(generation);

    final restoredDistance = _restoredDistance ?? 0;
    if (!_dataAccessAllowed) {
      return _neutralState.copyWith(distanceKm: restoredDistance);
    }
    return TripState(distanceKm: restoredDistance);
  }

  Future<void> _beginRestoration(int generation) {
    return _restoreOperation ??= Future<void>.microtask(
      () => _restoreDistance(generation),
    );
  }

  void _scheduleStartAfterRestoration(int generation) {
    if (_startQueued) return;
    _startQueued = true;

    unawaited(() async {
      try {
        await _beginRestoration(generation);
        if (!_isActive(generation)) return;
        await start(generation: generation);
      } finally {
        _startQueued = false;
      }
    }());
  }

  void _onSettingsReadinessChanged(bool allowed, int generation) {
    final wasAllowed = _dataAccessAllowed;
    _dataAccessAllowed = allowed;

    if (!allowed) {
      if (wasAllowed) {
        _disableTracking();
        state = TripState(
          distanceKm: _restoredDistance ?? state.distanceKm,
          available: false,
          hasFix: false,
        );
      }
      return;
    }

    if (!wasAllowed) {
      _watchLocationService();
      _scheduleStartAfterRestoration(generation);
    }
  }

  bool _isActive([int? generation]) {
    return !_disposed &&
        _dataAccessAllowed &&
        (generation == null || generation == _lifecycleGeneration);
  }

  bool _isGenerationActive(int generation) {
    return !_disposed && generation == _lifecycleGeneration;
  }

  bool _isStartActive(int lifecycleGeneration, int startGeneration) {
    return _isActive(lifecycleGeneration) &&
        startGeneration == _startGeneration;
  }

  static const TripState _neutralState = TripState(
    available: false,
    hasFix: false,
  );

  /// Stops the phone-side feed and removes its last values whenever persisted
  /// settings become unavailable. This prevents consumers from retaining a
  /// stale GPS reading across a provider reset.
  void _disableTracking() {
    _startGeneration++;
    _sub?.cancel();
    _sub = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _serviceStatusSub?.cancel();
    _serviceStatusSub = null;
    _filter.reset();
    // The local odometer belongs to persistence, not to GPS/settings access.
    // Keep it available while the operational feed is disabled.
    _backgroundServiceStarted = false;
    _stopBackgroundService();
  }

  void _stopBackgroundService() {
    final service = _backgroundService;
    _backgroundService = null;
    if (service != null) {
      unawaited(service.stop());
    }
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
          if (!_isActive()) return;
          debugPrint('GPS SERVICE STATUS UNAVAILABLE: $error');
        },
      );
    } catch (_) {
      // Platform without the plugin (tests, desktop) — nothing to watch.
    }
  }

  void _onServiceStatus(ServiceStatus status) {
    if (!_isActive()) return;

    if (status == ServiceStatus.enabled) {
      // Safe to call repeatedly: the queued start waits for restoration and
      // the current settings readiness before replacing the old stream.
      _scheduleStartAfterRestoration(_lifecycleGeneration);
    } else {
      _gpsWatchdog?.cancel();
      if (_isActive()) {
        state = state.copyWith(available: false, hasFix: false);
      }
    }
  }

  /// Brings back the distance saved by [_persist], so closing and reopening
  /// the app never wipes the odometer — only [resetTrip] zeroes it.
  Future<void> _restoreDistance([int? generation]) async {
    final operationGeneration = generation ?? _lifecycleGeneration;
    if (!_isGenerationActive(operationGeneration) || _restored) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isGenerationActive(operationGeneration)) return;
      final saved = prefs.getDouble('trip_distance_km');
      _restoredDistance = saved != null && saved >= 0 ? saved : null;
      // Only mark the session restored after the async read completes while
      // it still belongs to the active provider generation. If a rebuild
      // invalidates this operation, the next build must be allowed to retry.
      _restored = true;

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
  Future<void> start({int? generation}) async {
    final operationGeneration = generation ?? _lifecycleGeneration;
    if (!_isActive(operationGeneration)) return;
    final startGeneration = ++_startGeneration;

    _sub?.cancel();
    _sub = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _filter.reset();

    final LocationSettings settings;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isStartActive(operationGeneration, startGeneration)) return;
      if (!serviceEnabled) {
        state = state.copyWith(available: false, hasFix: false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (!_isStartActive(operationGeneration, startGeneration)) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!_isStartActive(operationGeneration, startGeneration)) return;
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
      if (_isStartActive(operationGeneration, startGeneration)) {
        state = state.copyWith(available: false, hasFix: false);
      }
      return;
    }

    if (!_isStartActive(operationGeneration, startGeneration)) return;

    state = state.copyWith(available: true, denied: false);

    // Keep fixes flowing while the app is in the background: run the keep
    // alive foreground service, which also acquires the location-capable
    // service type as soon as the permission is granted.
    _ensureBackgroundService(operationGeneration, startGeneration);
    if (!_isStartActive(operationGeneration, startGeneration)) return;

    try {
      _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
        (position) => _onFix(
          position,
          operationGeneration,
          startGeneration,
        ),
        onError: (_) {
          if (!_isStartActive(operationGeneration, startGeneration)) return;
          _gpsWatchdog?.cancel();
          state = state.copyWith(hasFix: false);
        },
      );

      _armGpsWatchdog(operationGeneration, startGeneration);
    } catch (error) {
      debugPrint('TRIP STREAM UNAVAILABLE: $error');
      if (_isStartActive(operationGeneration, startGeneration)) {
        state = state.copyWith(available: false, hasFix: false);
      }
    }
  }

  void _onFix(Position position, int lifecycleGeneration, int startGeneration) {
    if (!_isStartActive(lifecycleGeneration, startGeneration)) return;

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

    _armGpsWatchdog(lifecycleGeneration, startGeneration);

    unawaited(
      _persist(
        distanceChanged: reading.stepKm > 0,
        generation: lifecycleGeneration,
      ),
    );
  }

  /// Rearms the stale-feed watchdog on every accepted fix. When GPS goes
  /// silent (tunnel, signal loss, a throttled stream) the cards switch to
  /// "no fix" instead of clinging to a frozen speed — the odometer value
  /// itself is never touched.
  void _armGpsWatchdog(int lifecycleGeneration, int startGeneration) {
    if (!_isStartActive(lifecycleGeneration, startGeneration)) return;

    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer(_gpsSilenceTimeout, () {
      if (_isStartActive(lifecycleGeneration, startGeneration)) {
        state = state.copyWith(hasFix: false);
      }
    });
  }

  /// Zeroes the trip distance; speed keeps streaming.
  void resetTrip() {
    if (!_isActive()) return;

    _filter.reset();
    _restoredDistance = 0;
    state = state.copyWith(distanceKm: 0);
    unawaited(
      _persist(
        distanceChanged: true,
        generation: _lifecycleGeneration,
      ),
    );
  }

  void _ensureBackgroundService(
    int lifecycleGeneration,
    int startGeneration,
  ) {
    if (!_isStartActive(lifecycleGeneration, startGeneration)) return;
    if (_backgroundServiceStarted) {
      return;
    }

    final service = ref.read(backgroundConnectionServiceProvider);
    if (!_isStartActive(lifecycleGeneration, startGeneration)) return;

    _backgroundServiceStarted = true;
    _backgroundService = service;
    unawaited(_startBackgroundService(service));
  }

  Future<void> _startBackgroundService(
    BackgroundConnectionService service,
  ) async {
    try {
      await service.start();
      if (_disposed || !_dataAccessAllowed) {
        await service.stop();
      }
    } catch (error) {
      debugPrint('BACKGROUND SERVICE START FAILED: $error');
    }
  }

  /// Persists the values under the shared keys (`speed_kmh`,
  /// `trip_distance_km`) so car-screen integrations can read them without
  /// waiting for the app UI — and so [_restoreDistance] brings the odometer
  /// back after the app is closed and reopened. Writes are throttled
  /// unless the distance moved.
  Future<void> _persist({
    bool distanceChanged = false,
    int? generation,
  }) async {
    final operationGeneration = generation ?? _lifecycleGeneration;
    if (!_isActive(operationGeneration)) return;

    final now = DateTime.now();
    final due = distanceChanged ||
        now.difference(_lastPersist) >= const Duration(seconds: 2);
    if (!due) {
      return;
    }

    _lastPersist = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_isActive(operationGeneration)) return;

      // Snapshot both values before the first write. The second write is an
      // async gap too, so it must not read [state] after that gap.
      final speedKmh = state.speedKmh;
      final distanceKm = state.distanceKm;
      await prefs.setDouble('speed_kmh', speedKmh);
      if (!_isActive(operationGeneration)) return;
      await prefs.setDouble('trip_distance_km', distanceKm);
    } catch (_) {
      // A failed write must never break live readings; the next accepted
      // fix simply tries again.
    }
  }
}

final tripProvider = NotifierProvider<TripNotifier, TripState>(
  TripNotifier.new,
);
