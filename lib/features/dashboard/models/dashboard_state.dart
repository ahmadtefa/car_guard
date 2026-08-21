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
}