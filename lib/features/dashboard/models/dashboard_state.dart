class DashboardState {
  const DashboardState({
    this.connectionStatus = 'Disconnected',
    this.engineTemperature = '-- °C',
    this.batteryVoltage = '--.- V',
    this.voltageDifference = '--.- V',
    this.coolantLevel = '--',
    this.fanStatus = 'OFF',
    this.lastUpdated = '--:--:--',
  });

  final String connectionStatus;

  final String engineTemperature;

  final String batteryVoltage;

  final String voltageDifference;

  final String coolantLevel;

  final String fanStatus;

  /// Clock time of the last reading received from the device.
  final String lastUpdated;

  DashboardState copyWith({
    String? connectionStatus,
    String? engineTemperature,
    String? batteryVoltage,
    String? voltageDifference,
    String? coolantLevel,
    String? fanStatus,
    String? lastUpdated,
  }) {
    return DashboardState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      engineTemperature: engineTemperature ?? this.engineTemperature,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      voltageDifference: voltageDifference ?? this.voltageDifference,
      coolantLevel: coolantLevel ?? this.coolantLevel,
      fanStatus: fanStatus ?? this.fanStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
