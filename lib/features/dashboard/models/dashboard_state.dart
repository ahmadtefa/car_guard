/// Immutable state model for the dashboard feature.
///
/// This placeholder model keeps the feature structure ready for future domain
/// expansion without introducing behavior.
class DashboardState {
  /// Creates a dashboard state with immutable placeholder values.
  const DashboardState({
    this.connectionStatus = 'Disconnected',
    this.engineTemperature = '-- °C',
    this.batteryVoltage = '--.- V',
    this.voltageDifference = '--.- V',
    this.coolantLevel = '--',
  });

  /// Placeholder connection status string.
  final String connectionStatus;

  /// Placeholder engine temperature value.
  final String engineTemperature;

  /// Placeholder battery voltage value.
  final String batteryVoltage;

  /// Placeholder voltage difference value.
  final String voltageDifference;

  /// Placeholder coolant level value.
  final String coolantLevel;
}
