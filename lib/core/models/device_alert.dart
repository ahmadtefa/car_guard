/// Severity levels used by dashboard alerts.
enum AlertSeverity { info, warning, critical }

/// Convenience helpers for ordering alert severities.
extension AlertSeverityX on AlertSeverity {
  /// Sorting rank; higher means more urgent.
  int get rank => switch (this) {
        AlertSeverity.info => 0,
        AlertSeverity.warning => 1,
        AlertSeverity.critical => 2,
      };
}

/// A single alert raised from live device readings.
class DeviceAlert {
  /// Creates an alert with a stable [id] used for de-duplication.
  const DeviceAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  /// Stable identifier describing the alert kind (e.g. `engine_overheat`).
  final String id;

  /// Short headline shown in the banner and the notification.
  final String title;

  /// Human-readable details shown beneath the title.
  final String message;

  /// How urgent the alert is.
  final AlertSeverity severity;

  /// When the alert was raised.
  final DateTime timestamp;

  /// Whether this alert is of critical severity.
  bool get isCritical => severity == AlertSeverity.critical;

  @override
  String toString() => 'DeviceAlert($id, $severity)';
}
