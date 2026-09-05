import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/services/notification_service.dart';
import '../../dashboard/providers/readings_history_provider.dart';
import '../../dashboard/providers/trip_provider.dart';
import '../../dashboard/providers/voltage_delta_provider.dart';
import '../../license/providers/license_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/analysis_models.dart';
import '../services/analysis_engine.dart';

/// Statistics for the currently tracked trip (GPS-based, local only).
class TripSummary {
  const TripSummary({
    required this.available,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.durationSeconds,
  });

  final bool available;
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int durationSeconds;
}

/// Everything the Alerts & Analysis page renders.
class AnalysisState {
  const AnalysisState({
    required this.condition,
    required this.activeAlerts,
    required this.stats,
    required this.baseline,
    required this.predictions,
    required this.history,
    required this.trip,
    required this.tempSlopePerMin,
    required this.voltageDelta90s,
    required this.loaded,
  });

  final VehicleCondition condition;
  final List<AnalysisAlert> activeAlerts;
  final SessionStats stats;
  final BaselineStats baseline;
  final List<Prediction> predictions;
  final List<AlertHistoryEntry> history;
  final TripSummary trip;

  /// °C/min over the trailing 2 minutes, null until enough samples exist.
  final double? tempSlopePerMin;

  /// Voltage change of the last ~90 seconds, null until it can be told.
  final double? voltageDelta90s;

  /// False until the persisted baseline + history finished loading.
  final bool loaded;

  AnalysisState copyWith({
    VehicleCondition? condition,
    List<AnalysisAlert>? activeAlerts,
    SessionStats? stats,
    BaselineStats? baseline,
    List<Prediction>? predictions,
    List<AlertHistoryEntry>? history,
    TripSummary? trip,
    double? Function()? tempSlopePerMin,
    double? Function()? voltageDelta90s,
    bool? loaded,
  }) {
    return AnalysisState(
      condition: condition ?? this.condition,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      stats: stats ?? this.stats,
      baseline: baseline ?? this.baseline,
      predictions: predictions ?? this.predictions,
      history: history ?? this.history,
      trip: trip ?? this.trip,
      tempSlopePerMin:
          tempSlopePerMin != null ? tempSlopePerMin() : this.tempSlopePerMin,
      voltageDelta90s:
          voltageDelta90s != null ? voltageDelta90s() : this.voltageDelta90s,
      loaded: loaded ?? this.loaded,
    );
  }
}

/// Local-only analysis brain: consumes the SAME live stream as the
/// dashboard, keeps session statistics, a persisted cross-session baseline,
/// a persisted alert history, and produces probabilistic predictions.
///
/// No internet, no tracking, no heavy work: intake is O(1) per reading and
/// a full rules pass runs at most once every few seconds — or immediately
/// when something clearly changed (connection, fan, coolant, big jumps).
final analysisProvider =
    NotifierProvider<AnalysisNotifier, AnalysisState>(AnalysisNotifier.new);

class AnalysisNotifier extends Notifier<AnalysisState> {
  static const String _baselineKey = 'analysis_baseline_v1';
  static const String _historyKey = 'analysis_history_v1';
  static const int _maxHistory = 100;

  /// Full rules passes are throttled to this interval (the module streams
  /// about one reading per second, so this is ~4 readings between passes).
  static const Duration _evaluateInterval = Duration(seconds: 4);

  /// Notification re-fire guard per alert kind.
  static const Duration _notifyCooldown = Duration(minutes: 15);

  // Immediate pass triggers (clear changes in the data).
  static const double _tempJumpC = 0.5;
  static const double _voltJumpV = 0.2;

  SmartAlertTracker _tracker = SmartAlertTracker();

  bool _analysisAccessAllowed = false;
  int _accessGeneration = 0;
  int _protectedPersistenceGeneration = 0;
  Future<void>? _purgeProtectedPersistence;
  bool _purgedForCurrentLock = false;
  bool _everConnected = false;

  DateTime _lastPassAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _lastPassConnected = false;
  double _lastPassTemp = -1000;
  double _lastPassVolt = -1000;
  bool _lastPassFan = false;
  bool _lastPassCoolant = true;

  double _speedSum = 0;
  int _speedSamples = 0;
  double _maxSpeed = 0;
  DateTime? _tripStart;

  double _lastSpeedKmh = 0;
  bool _lastHasFix = false;

  int _connectedBaselineMinutes = 0;
  int _baselineSampleCount = 0;

  DateTime? _fanOnSince;
  bool _wasOverLimit = false;
  bool _voltageAbnormalLatched = false;

  final Map<AnalysisAlertKind, DateTime> _lastNotified = {};

  bool _baselineDirty = false;

  @override
  AnalysisState build() {
    final settingsReady = ref.watch(
      settingsProvider.select((value) => value.value != null),
    );
    final demoEnabled = ref.watch(
      settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
    );
    final license = ref.watch(licenseProvider);
    final authorized = license.canUseProtectedControls;
    // Analysis consumes real sensor data, so clear it while the module is
    // LOCKED/expired. Demo mode remains local and license-independent.
    final allowed = settingsReady && (demoEnabled || authorized);
    if (settingsReady && !demoEnabled && license.isLocked) {
      if (!_purgedForCurrentLock) {
        _purgedForCurrentLock = true;
        _purgeProtectedPersistence = _purgeStoredData();
      }
    } else if (authorized) {
      _purgedForCurrentLock = false;
    }
    final generation = ++_accessGeneration;
    _analysisAccessAllowed = allowed;

    if (!allowed) {
      _resetProtectedRuntime();
      // Do not expose stale values while persisted settings are still loading.
      return _emptyState(loaded: true);
    }

    ref.listen(
      deviceStatusProvider,
      (previous, next) {
        if (generation != _accessGeneration) return;
        next.whenData(_handleStatus);
      },
      fireImmediately: true,
    );

    // GPS moves on its own stream; keep the trip summary and the
    // connection-lost-while-driving rule fed between module readings.
    ref.listen(
      tripProvider,
      (previous, next) {
        if (generation != _accessGeneration) return;
        _handleTrip(next);
      },
      fireImmediately: true,
    );

    // Fire and forget: the persisted baseline + history land shortly after
    // and flip `loaded` once they are part of the state. The generation guard
    // prevents a stale load from repopulating analysis after access is lost.
    unawaited(_loadPersisted(generation));

    return _emptyState();
  }

  AnalysisState _emptyState({bool loaded = false}) {
    return AnalysisState(
      condition: VehicleCondition.normal,
      activeAlerts: const [],
      stats: const SessionStats(),
      baseline: const BaselineStats(),
      predictions: const [],
      history: const [],
      trip: const TripSummary(
        available: false,
        distanceKm: 0,
        avgSpeedKmh: 0,
        maxSpeedKmh: 0,
        durationSeconds: 0,
      ),
      tempSlopePerMin: null,
      voltageDelta90s: null,
      loaded: loaded,
    );
  }

  void _resetProtectedRuntime() {
    _tracker = SmartAlertTracker();
    _everConnected = false;
    _lastPassAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastPassConnected = false;
    _lastPassTemp = -1000;
    _lastPassVolt = -1000;
    _lastPassFan = false;
    _lastPassCoolant = true;
    _speedSum = 0;
    _speedSamples = 0;
    _maxSpeed = 0;
    _tripStart = null;
    _lastSpeedKmh = 0;
    _lastHasFix = false;
    _connectedBaselineMinutes = 0;
    _baselineSampleCount = 0;
    _fanOnSince = null;
    _wasOverLimit = false;
    _voltageAbnormalLatched = false;
    _lastNotified.clear();
    _baselineDirty = false;
  }

  // ------------------------------------------------------------------
  // Persistence
  // ------------------------------------------------------------------

  Future<void> _purgeStoredData() async {
    ++_protectedPersistenceGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_baselineKey),
        prefs.remove(_historyKey),
      ]);
    } catch (_) {}
    // The generation is intentionally retained: any write that started before
    // LOCKED must not recreate the purged temperature/voltage history.
  }

  Future<void> _loadPersisted(int generation) async {
    final purge = _purgeProtectedPersistence;
    if (purge != null) await purge;
    if (!_analysisAccessAllowed || generation != _accessGeneration) return;
    final persistenceGeneration = _protectedPersistenceGeneration;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_analysisAccessAllowed || generation != _accessGeneration) return;

      final baselineRaw = prefs.getString(_baselineKey);
      final historyRaw = prefs.getString(_historyKey);

      var baseline = baselineRaw == null
          ? const BaselineStats()
          : BaselineStats.fromJson(
              Map<String, dynamic>.from(jsonDecode(baselineRaw) as Map),
            );

      // One more app session that uses the analysis layer.
      baseline = baseline.copyWith(sessions: baseline.sessions + 1);

      final stored = historyRaw == null
          ? const <AlertHistoryEntry>[]
          : AlertHistoryEntry.decodeList(historyRaw);

      // Keep anything logged while the disk read was in flight (an alert can
      // fire within the first milliseconds if the app opens mid-problem).
      final merged = [...state.history];
      for (final entry in stored) {
        final exists = merged.any(
          (e) => e.kind == entry.kind && e.timestamp == entry.timestamp,
        );
        if (!exists) merged.add(entry);
      }
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (merged.length > _maxHistory) merged.length = _maxHistory;

      if (!_analysisAccessAllowed ||
          generation != _accessGeneration ||
          persistenceGeneration != _protectedPersistenceGeneration) {
        return;
      }

      state = state.copyWith(
        baseline: baseline,
        history: merged,
        loaded: true,
      );

      await _persistBaseline();
    } catch (_) {
      if (_analysisAccessAllowed && generation == _accessGeneration) {
        state = state.copyWith(loaded: true);
      }
    }
  }

  Future<void> _persistBaseline() async {
    if (!_analysisAccessAllowed) return;
    final persistenceGeneration = _protectedPersistenceGeneration;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_analysisAccessAllowed ||
          persistenceGeneration != _protectedPersistenceGeneration) {
        return;
      }
      await prefs.setString(_baselineKey, jsonEncode(state.baseline.toJson()));
    } catch (_) {}
  }

  Future<void> _persistHistory() async {
    if (!_analysisAccessAllowed) return;
    final persistenceGeneration = _protectedPersistenceGeneration;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_analysisAccessAllowed ||
          persistenceGeneration != _protectedPersistenceGeneration) {
        return;
      }
      await prefs.setString(
        _historyKey,
        AlertHistoryEntry.encodeList(state.history),
      );
    } catch (_) {}
  }

  /// Wipes the persisted alert history (page's clear-history action).
  Future<void> clearHistory() async {
    state = state.copyWith(history: const []);
    await _persistHistory();
  }

  // ------------------------------------------------------------------
  // Live data intake (O(1) per reading; heavy pass is throttled)
  // ------------------------------------------------------------------

  void _handleTrip(TripState trip) {
    if (!_analysisAccessAllowed) return;

    _lastSpeedKmh = trip.speedKmh;
    _lastHasFix = trip.hasFix;

    if (trip.hasFix) {
      _speedSum += trip.speedKmh;
      _speedSamples++;
      if (trip.speedKmh > _maxSpeed) _maxSpeed = trip.speedKmh;
      _tripStart ??= DateTime.now();
    }

    _maybeRunPass(null);
  }

  void _handleStatus(DeviceStatus? status) {
    if (!_analysisAccessAllowed) return;

    if (status != null && status.connected) {
      _everConnected = true;
      _accumulateSession(status);
    }
    _maybeRunPass(status);
  }

  /// Runs the full analysis pass when the interval passed OR the readings
  /// clearly changed — never on every raw tick.
  void _maybeRunPass(DeviceStatus? status) {
    if (!_analysisAccessAllowed) return;

    final now = DateTime.now();
    final connected = status?.connected ?? false;

    var significant = connected != _lastPassConnected;

    if (status != null) {
      final temp = status.temperatureData.engineTemperature;
      final volt = status.batteryData.voltage;
      if ((_lastPassTemp - temp).abs() >= _tempJumpC) significant = true;
      if ((_lastPassVolt - volt).abs() >= _voltJumpV) significant = true;
      if (status.controlData.fanRunning != _lastPassFan) significant = true;
      if (status.coolantLevelData.coolantAvailable != _lastPassCoolant) {
        significant = true;
      }
    }

    if (!significant && now.difference(_lastPassAt) < _evaluateInterval) {
      return;
    }

    _lastPassAt = now;
    _lastPassConnected = connected;
    if (status != null) {
      _lastPassTemp = status.temperatureData.engineTemperature;
      _lastPassVolt = status.batteryData.voltage;
      _lastPassFan = status.controlData.fanRunning;
      _lastPassCoolant = status.coolantLevelData.coolantAvailable;
    }

    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final history = ref.read(readingsHistoryProvider);
    final slope = AnalysisEngine.computeTempSlopeCPerMin(history);
    final voltageDelta = computeVoltageDelta(history);

    final limits = status?.moduleLimits;
    final readings = <String, double>{
      if (status != null) 'temp': status.temperatureData.engineTemperature,
      if (status != null) 'volt': status.batteryData.voltage,
      if (_lastHasFix) 'speed': _lastSpeedKmh,
      if (status != null) 'fan': status.controlData.fanRunning ? 1 : 0,
      if (status != null)
        'coolant': status.coolantLevelData.coolantAvailable ? 1 : 0,
      if (limits?.maxTemp != null) 'tempMax': limits!.maxTemp!,
      if (limits?.minVolt != null) 'voltMin': limits!.minVolt!,
      if (limits?.maxVolt != null) 'voltMax': limits!.maxVolt!,
      if (_fanOnSince != null)
        'fanMin': now.difference(_fanOnSince!).inMinutes.toDouble(),
    };

    _evaluateRules(status, settings, now, readings, slope, voltageDelta);

    _updateBaseline();

    _emitState(status, slope, voltageDelta);
  }

  void _accumulateSession(DeviceStatus status) {
    final stats = state.stats;
    final temp = status.temperatureData.engineTemperature;
    final volt = status.batteryData.voltage;

    var avgTemp = stats.avgTemp * stats.connectedSamples + temp;
    var avgVolt = stats.avgVoltage * stats.connectedSamples + volt;
    final samples = stats.connectedSamples + 1;
    avgTemp /= samples;
    avgVolt /= samples;

    var warningCrossings = stats.warningCrossings;
    final maxTemp = status.moduleLimits.maxTemp;
    final overLimit = maxTemp != null && temp >= maxTemp;
    if (overLimit && !_wasOverLimit) warningCrossings++;
    _wasOverLimit = overLimit;

    // Traffic-jam correlation bookkeeping: high temp + speed buckets.
    final heatBand = maxTemp != null
        ? maxTemp - AnalysisEngine.heatCorrelationTempOffsetC
        : 90.0;
    var slow = stats.highTempSlowSpeedSamples;
    var fast = stats.highTempFastSpeedSamples;
    if (temp >= heatBand && _lastHasFix) {
      if (_lastSpeedKmh < AnalysisEngine.slowSpeedKmh) {
        slow++;
      } else {
        fast++;
      }
    }

    var fanSeconds = stats.fanOnSeconds;
    if (status.controlData.fanRunning) {
      fanSeconds++;
      _fanOnSince ??= DateTime.now();
    } else {
      _fanOnSince = null;
    }

    _baselineSampleCount++;

    state = state.copyWith(
      stats: stats.copyWith(
        connectedSamples: samples,
        avgTemp: avgTemp,
        maxTemp: temp > stats.maxTemp ? temp : stats.maxTemp,
        avgVoltage: avgVolt,
        minVoltage:
            volt > 0 && volt < stats.minVoltage ? volt : stats.minVoltage,
        maxVoltage: volt > stats.maxVoltage ? volt : stats.maxVoltage,
        warningCrossings: warningCrossings,
        fanOnSeconds: fanSeconds,
        highTempSlowSpeedSamples: slow,
        highTempFastSpeedSamples: fast,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Alert rules -> smart tracker -> history + notifications
  // ------------------------------------------------------------------

  void _evaluateRules(
    DeviceStatus? status,
    AppSettings settings,
    DateTime now,
    Map<String, double> readings,
    double? slope,
    double? voltageDelta,
  ) {
    final connected = status?.connected ?? false;
    final temp = status?.temperatureData.engineTemperature ?? 0;
    final volt = status?.batteryData.voltage ?? 0;
    final limits = status?.moduleLimits;
    final maxTemp = limits?.maxTemp;

    // -- Engine over the module's own alarm limit ------------------------
    _track(
      AnalysisAlertKind.engineTempHigh,
      condition: connected && maxTemp != null && temp >= maxTemp,
      severity: AnalysisSeverity.danger,
      now: now,
      readings: readings,
    );

    // -- Battery below / above the module limits -------------------------
    _track(
      AnalysisAlertKind.batteryLow,
      condition: connected &&
          limits?.minVolt != null &&
          volt > 0 &&
          volt <= limits!.minVolt!,
      severity: AnalysisSeverity.warning,
      now: now,
      readings: readings,
    );
    _track(
      AnalysisAlertKind.batteryHigh,
      condition:
          connected && limits?.maxVolt != null && volt > limits!.maxVolt!,
      severity: AnalysisSeverity.warning,
      now: now,
      readings: readings,
    );

    // -- Abnormal 90-second voltage swing --------------------------------
    final abnormalVolt = connected &&
        voltageDelta != null &&
        voltageDelta.abs() > AnalysisEngine.abnormalVoltageDeltaV;
    if (abnormalVolt && !_voltageAbnormalLatched) {
      _voltageAbnormalLatched = true;
      state = state.copyWith(
        stats: state.stats.copyWith(
          abnormalVoltageChanges: state.stats.abnormalVoltageChanges + 1,
        ),
      );
    } else if (!abnormalVolt) {
      _voltageAbnormalLatched = false;
    }
    _track(
      AnalysisAlertKind.voltageUnstable,
      condition: abnormalVolt,
      severity: AnalysisSeverity.notice,
      now: now,
      readings: readings,
    );

    // -- Coolant low (only when the user enabled that sensor) ------------
    _track(
      AnalysisAlertKind.coolantLow,
      condition: connected &&
          settings.coolantAlertsEnabled &&
          !status!.coolantLevelData.coolantAvailable,
      severity: AnalysisSeverity.warning,
      now: now,
      readings: readings,
    );

    // -- Fan running continuously far longer than usual ------------------
    final fanLong = connected &&
        status!.controlData.fanRunning &&
        _fanOnSince != null &&
        now.difference(_fanOnSince!) >= AnalysisEngine.fanLongRunAfter;
    _track(
      AnalysisAlertKind.fanLongRun,
      condition: fanLong,
      severity: AnalysisSeverity.notice,
      now: now,
      readings: readings,
      onStarted: () {
        state = state.copyWith(
          stats: state.stats.copyWith(
            fanLongRunEpisodes: state.stats.fanLongRunEpisodes + 1,
          ),
        );
      },
    );

    // -- Connection lost while the car is actually moving ----------------
    _track(
      AnalysisAlertKind.connectionLostDriving,
      condition:
          !connected && _everConnected && _lastHasFix && _lastSpeedKmh > 20,
      severity: AnalysisSeverity.warning,
      now: now,
      readings: readings,
    );
  }

  void _track(
    AnalysisAlertKind kind, {
    required bool condition,
    required AnalysisSeverity severity,
    required DateTime now,
    required Map<String, double> readings,
    void Function()? onStarted,
  }) {
    final event = _tracker.update(
      kind,
      condition: condition,
      severity: severity,
      now: now,
      readings: readings,
    );

    if (event == AlertTrackerEvent.started) {
      onStarted?.call();
      _logHistory(_tracker.active[kind]!, escalated: false);
      unawaited(_maybeNotify(_tracker.active[kind]!));
    } else if (event == AlertTrackerEvent.escalated) {
      _logHistory(_tracker.active[kind]!, escalated: true);
      unawaited(_maybeNotify(_tracker.active[kind]!));
    }
  }

  void _logHistory(AnalysisAlert alert, {required bool escalated}) {
    final history = [...state.history];

    if (escalated) {
      // Update THE SAME episode's entry in place (newest entry of kind).
      final index = history.indexWhere((e) => e.kind == alert.kind);
      if (index >= 0) {
        history[index] = history[index].copyWith(
          severity: alert.severity,
          timestamp: alert.updatedAt,
          readings: alert.readings,
          occurrences: alert.occurrences,
          escalated: true,
        );
        state = state.copyWith(history: history);
        unawaited(_persistHistory());
        return;
      }
    }

    history.insert(
      0,
      AlertHistoryEntry(
        kind: alert.kind,
        severity: alert.severity,
        timestamp: alert.startedAt,
        readings: alert.readings,
        occurrences: alert.occurrences,
        escalated: false,
      ),
    );

    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }

    state = state.copyWith(history: history);
    unawaited(_persistHistory());
  }

  Future<void> _maybeNotify(AnalysisAlert alert) async {
    if (!_analysisAccessAllowed) return;

    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    if (!settings.alertsEnabled) return;

    final last = _lastNotified[alert.kind];
    final now = DateTime.now();
    if (last != null && now.difference(last) < _notifyCooldown) return;

    // Local notifications go out for real danger — a warning that just
    // opened stays on the page until the tracker escalates it.
    if (alert.severity != AnalysisSeverity.danger) return;

    _lastNotified[alert.kind] = now;

    final l = AppL10n(settings.languageName);
    final temp = (alert.readings['temp'] ?? 0).toStringAsFixed(1);
    final volt = (alert.readings['volt'] ?? 0).toStringAsFixed(2);
    final voltMin = (alert.readings['voltMin'] ?? 0).toStringAsFixed(2);
    final voltMax = (alert.readings['voltMax'] ?? 0).toStringAsFixed(2);

    final (title, body) = switch (alert.kind) {
      AnalysisAlertKind.engineTempHigh => (
          l.engineOverheatTitle,
          l.engineOverheatMessage(temp),
        ),
      AnalysisAlertKind.batteryLow => (
          l.batteryLowTitle,
          l.batteryLowMessage(volt, voltMin),
        ),
      AnalysisAlertKind.batteryHigh => (
          l.batteryHighTitle,
          l.batteryHighMessage(volt, voltMax),
        ),
      AnalysisAlertKind.voltageUnstable => (
          l.voltageUnstableTitle,
          l.voltageUnstableMessage,
        ),
      AnalysisAlertKind.coolantLow => (
          l.coolantLowTitle,
          l.coolantLowMessage,
        ),
      AnalysisAlertKind.fanLongRun => (
          l.fanLongRunTitle,
          l.fanLongRunMessage,
        ),
      AnalysisAlertKind.connectionLostDriving => (
          l.connectionLostTitle,
          l.connectionLostMessage,
        ),
    };

    try {
      await ref.read(notificationServiceProvider).show(
            title: title,
            body: body,
          );
    } catch (_) {
      // Notifications must never break the analysis loop.
    }
  }

  // ------------------------------------------------------------------
  // Baseline maintenance (cross-session, persisted, tiny writes)
  // ------------------------------------------------------------------

  void _updateBaseline() {
    // One baseline "minute" per 60 connected samples (~1/s stream).
    final minutesNow = _baselineSampleCount ~/ 60;
    if (minutesNow <= _connectedBaselineMinutes) return;
    _connectedBaselineMinutes = minutesNow;

    final baseline = state.baseline;
    final stats = state.stats;

    const alpha = 0.05; // slow EMA: recent weeks dominate, history counts

    final slope = state.tempSlopePerMin ?? 0;

    state = state.copyWith(
      baseline: baseline.copyWith(
        avgTemp: stats.avgTemp == 0
            ? baseline.avgTemp
            : baseline.avgTemp + alpha * (stats.avgTemp - baseline.avgTemp),
        avgVoltage: stats.avgVoltage == 0
            ? baseline.avgVoltage
            : baseline.avgVoltage +
                alpha * (stats.avgVoltage - baseline.avgVoltage),
        avgRiseRateCPerMin: baseline.avgRiseRateCPerMin +
            alpha * (slope - baseline.avgRiseRateCPerMin),
        minutesObserved: baseline.minutesObserved + 1,
      ),
    );

    _baselineDirty = !_baselineDirty;

    // Persist at most once every two baseline minutes.
    if (_baselineDirty) {
      unawaited(_persistBaseline());
    }
  }

  // ------------------------------------------------------------------
  // State emission
  // ------------------------------------------------------------------

  void _emitState(DeviceStatus? status, double? slope, double? voltageDelta) {
    final predictions = AnalysisEngine.buildPredictions(
      currentTemp: status?.temperatureData.engineTemperature ?? 0,
      slopeCPerMin: slope,
      maxTemp: status?.moduleLimits.maxTemp,
      voltageDelta90s: voltageDelta,
      currentVoltage: status?.batteryData.voltage ?? 0,
      stats: state.stats,
      baseline: state.baseline,
      slopeSampleCount: ref.read(readingsHistoryProvider).length,
    );

    final alerts = _tracker.activeAlerts();

    var condition = VehicleCondition.normal;
    for (final alert in alerts) {
      condition = _worst(condition, alert.severity);
    }
    for (final prediction in predictions) {
      condition = _worst(condition, prediction.severity);
    }
    if (!(status?.connected ?? false)) {
      // Parked with no live data never looks scarier than "attention".
      if (condition.index > VehicleCondition.attention.index) {
        condition = VehicleCondition.attention;
      }
    }

    final durationSeconds = _tripStart == null
        ? 0
        : DateTime.now().difference(_tripStart!).inSeconds;

    final trip = TripSummary(
      available: _speedSamples >= 5,
      distanceKm: ref.read(tripProvider).distanceKm,
      avgSpeedKmh: _speedSamples == 0 ? 0 : _speedSum / _speedSamples,
      maxSpeedKmh: _maxSpeed,
      durationSeconds: durationSeconds,
    );

    state = state.copyWith(
      condition: condition,
      activeAlerts: alerts,
      predictions: predictions,
      trip: trip,
      tempSlopePerMin: () => slope,
      voltageDelta90s: () => voltageDelta,
    );
  }

  VehicleCondition _worst(VehicleCondition a, AnalysisSeverity severity) {
    final mapped = switch (severity) {
      AnalysisSeverity.notice => VehicleCondition.attention,
      AnalysisSeverity.warning => VehicleCondition.warning,
      AnalysisSeverity.danger => VehicleCondition.danger,
    };
    return mapped.index > a.index ? mapped : a;
  }
}
