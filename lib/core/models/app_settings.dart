import 'dart:convert';

/// User-configurable application settings persisted on the device.
///
/// A single instance holds everything the app needs to remember between runs:
/// the address of the Car Guard ESP8266 module and the thresholds that drive
/// dashboard alerts and local notifications.
class AppSettings {
  /// Creates a settings snapshot with sensible defaults for a stock
  /// ESP8266 Car Guard module.
  const AppSettings({
    this.deviceHost = '192.168.4.1',
    this.devicePort = 81,
    this.alertsEnabled = true,
    this.coolantAlertsEnabled = true,
    this.connectionAlertsEnabled = true,
    this.engineTempWarning = 100,
    this.engineTempCritical = 110,
    this.minBatteryVoltage = 12.2,
    this.alertCooldown = const Duration(minutes: 5),
    this.demoModeEnabled = false,
    this.themeModeName = 'system',
    this.maxBatteryVoltage = 15.0,
    this.dashboardStyleName = 'cards',
  });

  /// Theme preference names accepted by [themeModeName].
  static const List<String> themeModeNames = ['system', 'light', 'dark'];

  /// Dashboard gauge styles accepted by [dashboardStyleName].
  static const List<String> dashboardStyleNames = [
    'cards',
    'racing',
    'sporty',
    'segments',
    'sweeper',
  ];

  /// Storage key used to persist the serialized settings.
  static const String storageKey = 'app_settings';

  /// Address of the ESP8266 module (IP or mDNS host name).
  final String deviceHost;

  /// WebSocket port used for live updates (HTTP falls back to port 80).
  final int devicePort;

  /// Master switch for every alert-driven notification.
  final bool alertsEnabled;

  /// Whether low coolant should raise an alert.
  final bool coolantAlertsEnabled;

  /// Whether losing the device connection should raise an alert.
  final bool connectionAlertsEnabled;

  /// Engine temperature (°C) at which a warning alert is raised.
  final double engineTempWarning;

  /// Engine temperature (°C) at which a critical alert is raised.
  final double engineTempCritical;

  /// Battery voltage (V) below which a low-battery alert is raised.
  final double minBatteryVoltage;

  /// Minimum delay before the same alert id may notify again.
  final Duration alertCooldown;

  /// When true, readings come from the built-in device simulator.
  final bool demoModeEnabled;

  /// Theme preference: 'system', 'light' or 'dark'.
  final String themeModeName;

  /// Battery voltage (V) above which a high-voltage alert is raised.
  final double maxBatteryVoltage;

  /// Dashboard gauge style: one of [dashboardStyleNames].
  final String dashboardStyleName;

  /// Returns a copy of this settings with the given fields replaced.
  AppSettings copyWith({
    String? deviceHost,
    int? devicePort,
    bool? alertsEnabled,
    bool? coolantAlertsEnabled,
    bool? connectionAlertsEnabled,
    double? engineTempWarning,
    double? engineTempCritical,
    double? minBatteryVoltage,
    Duration? alertCooldown,
    bool? demoModeEnabled,
    String? themeModeName,
    double? maxBatteryVoltage,
    String? dashboardStyleName,
  }) {
    return AppSettings(
      deviceHost: deviceHost ?? this.deviceHost,
      devicePort: devicePort ?? this.devicePort,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      coolantAlertsEnabled: coolantAlertsEnabled ?? this.coolantAlertsEnabled,
      connectionAlertsEnabled:
          connectionAlertsEnabled ?? this.connectionAlertsEnabled,
      engineTempWarning: engineTempWarning ?? this.engineTempWarning,
      engineTempCritical: engineTempCritical ?? this.engineTempCritical,
      minBatteryVoltage: minBatteryVoltage ?? this.minBatteryVoltage,
      alertCooldown: alertCooldown ?? this.alertCooldown,
      demoModeEnabled: demoModeEnabled ?? this.demoModeEnabled,
      themeModeName: themeModeName ?? this.themeModeName,
      maxBatteryVoltage: maxBatteryVoltage ?? this.maxBatteryVoltage,
      dashboardStyleName: dashboardStyleName ?? this.dashboardStyleName,
    );
  }

  /// Serializes the settings to the JSON map persisted in storage.
  Map<String, dynamic> toJson() {
    return {
      'deviceHost': deviceHost,
      'devicePort': devicePort,
      'alertsEnabled': alertsEnabled,
      'coolantAlertsEnabled': coolantAlertsEnabled,
      'connectionAlertsEnabled': connectionAlertsEnabled,
      'engineTempWarning': engineTempWarning,
      'engineTempCritical': engineTempCritical,
      'minBatteryVoltage': minBatteryVoltage,
      'alertCooldownMinutes': alertCooldown.inMinutes,
      'demoModeEnabled': demoModeEnabled,
      'themeModeName': themeModeName,
      'maxBatteryVoltage': maxBatteryVoltage,
      'dashboardStyleName': dashboardStyleName,
    };
  }

  /// Builds settings from a persisted JSON map, falling back to defaults
  /// for any missing or invalid entry.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      deviceHost: json['deviceHost'] as String? ?? '192.168.4.1',
      devicePort: json['devicePort'] as int? ?? 81,
      alertsEnabled: json['alertsEnabled'] as bool? ?? true,
      coolantAlertsEnabled: json['coolantAlertsEnabled'] as bool? ?? true,
      connectionAlertsEnabled:
          json['connectionAlertsEnabled'] as bool? ?? true,
      engineTempWarning:
          (json['engineTempWarning'] as num?)?.toDouble() ?? 100,
      engineTempCritical:
          (json['engineTempCritical'] as num?)?.toDouble() ?? 110,
      minBatteryVoltage:
          (json['minBatteryVoltage'] as num?)?.toDouble() ?? 12.2,
      alertCooldown: Duration(
        minutes: json['alertCooldownMinutes'] as int? ?? 5,
      ),
      demoModeEnabled: json['demoModeEnabled'] as bool? ?? false,
      themeModeName:
          themeModeNames.contains(json['themeModeName'] as String?)
          ? json['themeModeName'] as String
          : 'system',
      maxBatteryVoltage:
          (json['maxBatteryVoltage'] as num?)?.toDouble() ?? 15.0,
      dashboardStyleName:
          dashboardStyleNames.contains(json['dashboardStyleName'] as String?)
          ? json['dashboardStyleName'] as String
          : 'cards',
    );
  }

  /// Encodes the settings as a JSON string ready for storage.
  String encode() => jsonEncode(toJson());

  /// Decodes settings from a raw JSON string, returning defaults when the
  /// payload cannot be parsed.
  factory AppSettings.fromRaw(String? raw) {
    if (raw == null || raw.isEmpty) return const AppSettings();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AppSettings();
      return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const AppSettings();
    }
  }
}
