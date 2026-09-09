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

  /// The saved odometer is loaded only once per settings session — later
  /// [start] calls (permission re-grant, manual restart) must not rewind the
  /// live counter to whatever happens to be on disk.
  bool _restored = false;

  /// The latest value read from storage, retained while settings are still
  /// loading so the first allowed build can expose it without losing it.
  double? _restoredDistance;

  /// True once persisted settings are ready. GPS/trip state is read-only and
  /// does not grant or bypass any protected module command.
  bool _dataAccessAllowed = false;

  /// Invalidates microtasks and async GPS/restore operations from an older
  /// provider build. A settings change can rebuild the notifier while an
  /// earlier permission or preferences call is still awaiting.
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

  // Temporary lifecycle tracing. This is intentionally kept while the local
  // Trip persistence failure is being reproduced and will be removed before
  // the production fix is committed.
  String get _traceId => '${identityHashCode(this)}';

  String _traceDistance() {
    try {
      return state.distanceKm.toString();
    } catch (_) {
      return '<uninitialized>';
    }
  }

  void _trace(String message) {
    debugPrint('TRIP TRACE [$_traceId] $message');
  }

  void _setStateWithTrace(TripState next, String source) {
    _trace(
      'state <- $source: distance ${_traceDistance()} -> '
      '${next.distanceKm}, available=${next.available}, '
      'hasFix=${next.hasFix}, denied=${next.denied}',
    );
    state = next;
  }

  @override
  TripState build() {
    _trace(
      'build start: disposed=$_disposed, restored=$_restored, '
      'restoredDistance=$_restoredDistance, '
      'dataAccessAllowed=$_dataAccessAllowed, '
      'lifecycleGeneration=$_lifecycleGeneration, '
      'stateDistance=${_traceDistance()}',
    );
    final generation = ++_lifecycleGeneration;
    final settingsReady = ref.watch(
      settingsProvider.select((value) => value.value != null),
    );
    // GPS/trip cards are read-only telemetry and are not a hardware control.
    // Keep them available for an unlicensed module just like temperature and
    // voltage readings.
    final allowed = settingsReady;
    final wasAllowed = _dataAccessAllowed;
    // A dependency rebuild must not replace a restored/live odometer with a
    // fresh zero state. The initial allowed build still starts at zero and
    // _restoreDistance fills it from SharedPreferences asynchronously.
    final preservedState = allowed && wasAllowed ? state : null;
    _dataAccessAllowed = allowed;
    _trace(
      'build computed: generation=$generation, settingsReady=$settingsReady, '
      'allowed=$allowed, wasAllowed=$wasAllowed, '
      'preservedDistance=${preservedState?.distanceKm}, '
      'restored=$_restored, restoredDistance=$_restoredDistance, '
      'stateDistance=${_traceDistance()}',
    );

    if (!allowed && wasAllowed) {
      _disableTracking();
    } else if (allowed && !wasAllowed) {
      _watchLocationService();
    }

    ref.onDispose(() {
      _trace(
        'onDispose start: disposed=$_disposed, restored=$_restored, '
        'restoredDistance=$_restoredDistance, '
        'dataAccessAllowed=$_dataAccessAllowed, '
        'lifecycleGeneration=$_lifecycleGeneration, '
        'stateDistance=${_traceDistance()}',
      );
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
      _backgroundServiceStarted = false;
      _restoredDistance = null;
      _stopBackgroundService();
      _trace(
        'onDispose end: disposed=$_disposed, restored=$_restored, '
        'restoredDistance=$_restoredDistance, '
        'dataAccessAllowed=$_dataAccessAllowed, '
        'lifecycleGeneration=$_lifecycleGeneration, '
        'stateDistance=${_traceDistance()}',
      );
    });

    // Restore the local odometer as soon as this provider generation is
    // alive. Starting GPS remains gated by settings readiness below, but a
    // settings load must not prevent a saved trip value from being read.
    Future<void>.microtask(() async {
      _trace(
        'restore microtask entered: generation=$generation, '
        'disposed=$_disposed, restored=$_restored, '
        'restoredDistance=$_restoredDistance, '
        'dataAccessAllowed=$_dataAccessAllowed, '
        'stateDistance=${_traceDistance()}',
      );
      if (!_isGenerationActive(generation)) {
        _trace('restore microtask stopped: generation is not active');
        return;
      }
      await _restoreDistance(generation);
      if (!_isActive(generation)) {
        _trace(
          'start stopped after restore: generation is not active or access is '
          'not allowed; stateDistance=${_traceDistance()}',
        );
        return;
      }
      await start(generation: generation);
    });

    if (preservedState != null) {
      _trace('build return preservedState distance=${preservedState.distanceKm}');
      return preservedState;
    }
    if (!allowed) {
      final restoredDistance = _restoredDistance;
      final next = restoredDistance == null
          ? _neutralState
          : _neutralState.copyWith(distanceKm: restoredDistance);
      _trace('build return not allowed distance=${next.distanceKm}');
      return next;
    }
    final next = TripState(distanceKm: _restoredDistance ?? 0);
    _trace('build return allowed distance=${next.distanceKm}');
    return next;
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
    _trace(
      'disableTracking start: restored=$_restored, '
      'restoredDistance=$_restoredDistance, dataAccessAllowed=$_dataAccessAllowed, '
      'stateDistance=${_traceDistance()}',
    );
    _startGeneration++;
    _sub?.cancel();
    _sub = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    _serviceStatusSub?.cancel();
    _serviceStatusSub = null;
    _filter.reset();
    _restored = false;
    _restoredDistance = null;
    _backgroundServiceStarted = false;
    _stopBackgroundService();
    _trace(
      'disableTracking end: restored=$_restored, '
      'restoredDistance=$_restoredDistance, dataAccessAllowed=$_dataAccessAllowed, '
      'stateDistance=${_traceDistance()}',
    );
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
      // Safe to call repeatedly: the old stream is replaced. Capture the
      // current generation so a later rebuild cancels this start operation.
      unawaited(start(generation: _lifecycleGeneration));
    } else {
      _gpsWatchdog?.cancel();
      if (_isActive()) {
        _setStateWithTrace(
          state.copyWith(available: false, hasFix: false),
          'service-disabled',
        );
      }
    }
  }

  /// Brings back the distance saved by [_persist], so closing and reopening
  /// the app never wipes the odometer — only [resetTrip] zeroes it.
  Future<void> _restoreDistance([int? generation]) async {
    final operationGeneration = generation ?? _lifecycleGeneration;
    _trace(
      'restore enter: operationGeneration=$operationGeneration, '
      'lifecycleGeneration=$_lifecycleGeneration, disposed=$_disposed, '
      'restored=$_restored, restoredDistance=$_restoredDistance, '
      'dataAccessAllowed=$_dataAccessAllowed, stateDistance=${_traceDistance()}',
    );
    if (!_isGenerationActive(operationGeneration) || _restored) {
      _trace('restore skipped: generation inactive or already restored');
      return;
    }
    try {
      _trace('restore awaiting SharedPreferences.getInstance()');
      final prefs = await SharedPreferences.getInstance();
      _trace(
        'restore acquired prefs=${identityHashCode(prefs)}; '
        'operationGeneration=$operationGeneration, '
        'lifecycleGeneration=$_lifecycleGeneration, disposed=$_disposed',
      );
      if (!_isGenerationActive(operationGeneration)) {
        _trace('restore stopped after getInstance: generation inactive');
        return;
      }
      final saved = prefs.getDouble('trip_distance_km');
      _trace('restore getDouble trip_distance_km -> $saved');
      final oldRestoredDistance = _restoredDistance;
      _restoredDistance = saved != null && saved >= 0 ? saved : null;
      _trace(
        'restoredDistance changed: $oldRestoredDistance -> $_restoredDistance',
      );
      // Only mark the session restored after the async read completes while
      // it still belongs to the active provider generation. If a rebuild
      // invalidates this operation, the next build must be allowed to retry.
      _restored = true;
      _trace('restored flag changed: false -> true');

      if (saved != null && saved > 0 && state.distanceKm == 0) {
        _setStateWithTrace(
          state.copyWith(distanceKm: saved),
          'restore($operationGeneration)',
        );
      } else {
        _trace(
          'restore did not assign state: saved=$saved, '
          'stateDistance=${_traceDistance()}',
        );
      }
    } catch (error, stackTrace) {
      _trace('restore failed: $error\n$stackTrace');
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
        _setStateWithTrace(
          state.copyWith(available: false, hasFix: false),
          'start-service-disabled',
        );
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
        _setStateWithTrace(
          state.copyWith(denied: true, hasFix: false),
          'start-permission-denied',
        );
        return;
      }

      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    } catch (error) {
      debugPrint('TRIP TRACKER UNAVAILABLE: $error');
      if (_isStartActive(operationGeneration, startGeneration)) {
        _setStateWithTrace(
          state.copyWith(available: false, hasFix: false),
          'start-check-error',
        );
      }
      return;
    }

    if (!_isStartActive(operationGeneration, startGeneration)) return;

    _setStateWithTrace(
      state.copyWith(available: true, denied: false),
      'start-available',
    );

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
          _setStateWithTrace(
            state.copyWith(hasFix: false),
            'stream-error',
          );
        },
      );

      _armGpsWatchdog(operationGeneration, startGeneration);
    } catch (error) {
      debugPrint('TRIP STREAM UNAVAILABLE: $error');
      if (_isStartActive(operationGeneration, startGeneration)) {
        _setStateWithTrace(
          state.copyWith(available: false, hasFix: false),
          'stream-start-error',
        );
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

    _setStateWithTrace(
      state.copyWith(
        speedKmh: reading.speedKmh,
        distanceKm: state.distanceKm + reading.stepKm,
        hasFix: true,
      ),
      'gps-fix',
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
        _setStateWithTrace(
          state.copyWith(hasFix: false),
          'gps-watchdog',
        );
      }
    });
  }

  /// Zeroes the trip distance; speed keeps streaming.
  void resetTrip() {
    _trace(
      'resetTrip called: disposed=$_disposed, restored=$_restored, '
      'restoredDistance=$_restoredDistance, dataAccessAllowed=$_dataAccessAllowed, '
      'stateDistance=${_traceDistance()}',
    );
    if (!_isActive()) {
      _trace('resetTrip stopped: provider is not active');
      return;
    }

    _filter.reset();
    final oldRestoredDistance = _restoredDistance;
    _restoredDistance = 0;
    _trace('restoredDistance changed by reset: $oldRestoredDistance -> 0');
    _setStateWithTrace(
      state.copyWith(distanceKm: 0),
      'resetTrip',
    );
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
    _trace(
      'persist enter: operationGeneration=$operationGeneration, '
      'distanceChanged=$distanceChanged, disposed=$_disposed, '
      'dataAccessAllowed=$_dataAccessAllowed, stateDistance=${_traceDistance()}',
    );
    if (!_isActive(operationGeneration)) {
      _trace('persist stopped: provider is not active');
      return;
    }

    final now = DateTime.now();
    final due = distanceChanged ||
        now.difference(_lastPersist) >= const Duration(seconds: 2);
    if (!due) {
      _trace('persist skipped: throttle due=$due');
      return;
    }

    _lastPersist = now;

    try {
      _trace('persist awaiting SharedPreferences.getInstance()');
      final prefs = await SharedPreferences.getInstance();
      _trace(
        'persist acquired prefs=${identityHashCode(prefs)}; '
        'operationGeneration=$operationGeneration, '
        'lifecycleGeneration=$_lifecycleGeneration, disposed=$_disposed',
      );
      if (!_isActive(operationGeneration)) {
        _trace('persist stopped after getInstance: provider is not active');
        return;
      }

      // Snapshot both values before the first write. The second write is an
      // async gap too, so it must not read [state] after that gap.
      final speedKmh = state.speedKmh;
      final distanceKm = state.distanceKm;
      _trace(
        'persist snapshot: speed=$speedKmh, distance=$distanceKm; '
        'writing speed_kmh',
      );
      await prefs.setDouble('speed_kmh', speedKmh);
      if (!_isActive(operationGeneration)) {
        _trace('persist stopped before trip_distance_km write');
        return;
      }
      _trace('persist writing trip_distance_km=$distanceKm');
      await prefs.setDouble('trip_distance_km', distanceKm);
      _trace('persist completed trip_distance_km=$distanceKm');
    } catch (error, stackTrace) {
      _trace('persist failed: $error\n$stackTrace');
      // A failed write must never break live readings; the next accepted
      // fix simply tries again.
    }
  }
}

final tripProvider = NotifierProvider<TripNotifier, TripState>(
  TripNotifier.new,
);
