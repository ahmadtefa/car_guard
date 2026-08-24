import 'dart:convert';

/// Severity tiers used by the local analysis layer (kept independent from
/// the dashboard's own alert severities so both systems stay decoupled).
enum AnalysisSeverity { notice, warning, danger }

extension AnalysisSeverityX on AnalysisSeverity {
  /// Higher rank = more urgent; used for sorting and for one-step
  /// escalation when a problem persists past its cooldown.
  int get rank => switch (this) {
        AnalysisSeverity.notice => 0,
        AnalysisSeverity.warning => 1,
        AnalysisSeverity.danger => 2,
      };

  /// One step up, capped at [AnalysisSeverity.danger].
  AnalysisSeverity get escalated => switch (this) {
        AnalysisSeverity.notice => AnalysisSeverity.warning,
        AnalysisSeverity.warning => AnalysisSeverity.danger,
        AnalysisSeverity.danger => AnalysisSeverity.danger,
      };
}

/// Overall vehicle condition shown at the top of the analysis page.
enum VehicleCondition { normal, attention, warning, danger }

/// Alert kinds the local analysis engine can raise.
///
/// The enum VALUES are the stable ids stored in history and matched by the
/// UI; their TEXT is produced by AppL10n at render/notification time so a
/// language switch re-localizes even old history entries.
enum AnalysisAlertKind {
  engineTempHigh,
  batteryLow,
  batteryHigh,
  voltageUnstable,
  coolantLow,
  fanLongRun,
  connectionLostDriving,
}

/// One alert episode tracked by the smart engine: opened when the
/// condition starts, updated while it persists, closed after it clears.
class AnalysisAlert {
  const AnalysisAlert({
    required this.kind,
    required this.severity,
    required this.startedAt,
    required this.updatedAt,
    required this.occurrences,
    required this.readings,
  });

  final AnalysisAlertKind kind;
  final AnalysisSeverity severity;

  /// First reading where the current episode held.
  final DateTime startedAt;

  /// Timestamp of the last fire (episode start or latest escalation) —
  /// the anchor the escalation cooldown is measured from.
  final DateTime updatedAt;

  /// How many times this episode fired (first fire + re-fires that were
  /// allowed by the cooldown — those are exactly the escalation points).
  final int occurrences;

  /// Key sensor values captured at the last fire (temp, volt, speed...).
  final Map<String, double> readings;

  AnalysisAlert copyWith({
    AnalysisSeverity? severity,
    DateTime? updatedAt,
    int? occurrences,
    Map<String, double>? readings,
  }) {
    return AnalysisAlert(
      kind: kind,
      severity: severity ?? this.severity,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      occurrences: occurrences ?? this.occurrences,
      readings: readings ?? this.readings,
    );
  }
}

/// Persisted alert-history entry (one per episode, updated on escalation).
class AlertHistoryEntry {
  const AlertHistoryEntry({
    required this.kind,
    required this.severity,
    required this.timestamp,
    required this.readings,
    required this.occurrences,
    required this.escalated,
  });

  final AnalysisAlertKind kind;
  final AnalysisSeverity severity;
  final DateTime timestamp;
  final Map<String, double> readings;
  final int occurrences;

  /// True once the episode escalated at least one tier.
  final bool escalated;

  AlertHistoryEntry copyWith({
    AnalysisSeverity? severity,
    DateTime? timestamp,
    Map<String, double>? readings,
    int? occurrences,
    bool? escalated,
  }) {
    return AlertHistoryEntry(
      kind: kind,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      readings: readings ?? this.readings,
      occurrences: occurrences ?? this.occurrences,
      escalated: escalated ?? this.escalated,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'severity': severity.name,
        'timestamp': timestamp.toIso8601String(),
        'readings': readings,
        'occurrences': occurrences,
        'escalated': escalated,
      };

  factory AlertHistoryEntry.fromJson(Map<String, dynamic> json) {
    return AlertHistoryEntry(
      kind: AnalysisAlertKind.values.asNameMap()[json['kind']] ??
          AnalysisAlertKind.engineTempHigh,
      severity: AnalysisSeverity.values.asNameMap()[json['severity']] ??
          AnalysisSeverity.notice,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
      readings: (json['readings'] as Map?)?.map(
            (key, value) => MapEntry('$key', (value as num).toDouble()),
          ) ??
          const {},
      occurrences: json['occurrences'] as int? ?? 1,
      escalated: json['escalated'] as bool? ?? false,
    );
  }

  static String encodeList(List<AlertHistoryEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  static List<AlertHistoryEntry> decodeList(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => AlertHistoryEntry.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Session-accumulated statistics (reset when the app restarts).
class SessionStats {
  const SessionStats({
    this.connectedSamples = 0,
    this.avgTemp = 0,
    this.maxTemp = -1000,
    this.avgVoltage = 0,
    this.minVoltage = 1000,
    this.maxVoltage = -1000,
    this.warningCrossings = 0,
    this.fanOnSeconds = 0,
    this.abnormalVoltageChanges = 0,
    this.highTempSlowSpeedSamples = 0,
    this.highTempFastSpeedSamples = 0,
    this.fanLongRunEpisodes = 0,
  });

  final int connectedSamples;
  final double avgTemp;
  final double maxTemp;
  final double avgVoltage;
  final double minVoltage;
  final double maxVoltage;

  /// Times the temperature crossed the module alarm limit this session.
  final int warningCrossings;

  /// Total seconds the cooling fan ran in this session.
  final int fanOnSeconds;

  /// Times the 90-second voltage delta exceeded the abnormality threshold.
  final int abnormalVoltageChanges;

  /// High-temperature readings split by vehicle speed (low-speed = the
  /// traffic-jam correlation signal).
  final int highTempSlowSpeedSamples;
  final int highTempFastSpeedSamples;

  /// Times the fan ran continuously longer than the expected window.
  final int fanLongRunEpisodes;

  SessionStats copyWith({
    int? connectedSamples,
    double? avgTemp,
    double? maxTemp,
    double? avgVoltage,
    double? minVoltage,
    double? maxVoltage,
    int? warningCrossings,
    int? fanOnSeconds,
    int? abnormalVoltageChanges,
    int? highTempSlowSpeedSamples,
    int? highTempFastSpeedSamples,
    int? fanLongRunEpisodes,
  }) {
    return SessionStats(
      connectedSamples: connectedSamples ?? this.connectedSamples,
      avgTemp: avgTemp ?? this.avgTemp,
      maxTemp: maxTemp ?? this.maxTemp,
      avgVoltage: avgVoltage ?? this.avgVoltage,
      minVoltage: minVoltage ?? this.minVoltage,
      maxVoltage: maxVoltage ?? this.maxVoltage,
      warningCrossings: warningCrossings ?? this.warningCrossings,
      fanOnSeconds: fanOnSeconds ?? this.fanOnSeconds,
      abnormalVoltageChanges:
          abnormalVoltageChanges ?? this.abnormalVoltageChanges,
      highTempSlowSpeedSamples:
          highTempSlowSpeedSamples ?? this.highTempSlowSpeedSamples,
      highTempFastSpeedSamples:
          highTempFastSpeedSamples ?? this.highTempFastSpeedSamples,
      fanLongRunEpisodes: fanLongRunEpisodes ?? this.fanLongRunEpisodes,
    );
  }
}

/// Cross-session baseline of "usual" vehicle behaviour, persisted locally.
///
/// Values are exponential moving averages: every connected minute nudges
/// them a little, so recent weeks weigh more than the distant past.
class BaselineStats {
  const BaselineStats({
    this.avgTemp = 0,
    this.avgVoltage = 0,
    this.avgRiseRateCPerMin = 0,
    this.minutesObserved = 0,
    this.sessions = 0,
  });

  final double avgTemp;
  final double avgVoltage;
  final double avgRiseRateCPerMin;

  /// Total minutes of connected readings that shaped the baseline.
  final double minutesObserved;
  final int sessions;

  /// A baseline is usable for "higher/lower than usual" comparisons only
  /// after enough real driving was observed.
  bool get isUsable => minutesObserved >= 30;

  BaselineStats copyWith({
    double? avgTemp,
    double? avgVoltage,
    double? avgRiseRateCPerMin,
    double? minutesObserved,
    int? sessions,
  }) {
    return BaselineStats(
      avgTemp: avgTemp ?? this.avgTemp,
      avgVoltage: avgVoltage ?? this.avgVoltage,
      avgRiseRateCPerMin: avgRiseRateCPerMin ?? this.avgRiseRateCPerMin,
      minutesObserved: minutesObserved ?? this.minutesObserved,
      sessions: sessions ?? this.sessions,
    );
  }

  Map<String, dynamic> toJson() => {
        'avgTemp': avgTemp,
        'avgVoltage': avgVoltage,
        'avgRiseRateCPerMin': avgRiseRateCPerMin,
        'minutesObserved': minutesObserved,
        'sessions': sessions,
      };

  factory BaselineStats.fromJson(Map<String, dynamic> json) {
    return BaselineStats(
      avgTemp: (json['avgTemp'] as num?)?.toDouble() ?? 0,
      avgVoltage: (json['avgVoltage'] as num?)?.toDouble() ?? 0,
      avgRiseRateCPerMin:
          (json['avgRiseRateCPerMin'] as num?)?.toDouble() ?? 0,
      minutesObserved: (json['minutesObserved'] as num?)?.toDouble() ?? 0,
      sessions: json['sessions'] as int? ?? 0,
    );
  }
}

/// Prediction kinds — text is localized at render time, never stored.
enum PredictionKind {
  overheatLikely,
  tempRisingFasterThanUsual,
  unusualVoltagePattern,
  coolingSystemCheckSuggested,
  heatRepeatedAtLowSpeed,
  approachingLimit,
}

/// One probabilistic hint produced by the local prediction rules.
class Prediction {
  const Prediction({
    required this.kind,
    required this.confidence,
    required this.severity,
    this.valueArg = '',
  });

  final PredictionKind kind;

  /// 0-100 computed FROM data quantities, or null when there is not enough
  /// data to make the call — the UI then shows "insufficient data".
  final int? confidence;

  final AnalysisSeverity severity;

  /// Optional pre-formatted argument for the localized text (e.g. "8.2").
  final String valueArg;
}
