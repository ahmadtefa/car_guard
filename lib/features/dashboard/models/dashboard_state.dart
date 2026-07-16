class DashboardState {
  const DashboardState({
    this.connectionStatus = 'Disconnected',
    this.engineTemperature = '-- °C',
    this.batteryVoltage = '--.- V',
    this.voltageDifference = '--.- V',
    this.coolantLevel = '--',
    this.fanStatus = 'OFF',
  });

  final String connectionStatus;

  final String engineTemperature;

  final String batteryVoltage;

  final String voltageDifference;

  final String coolantLevel;

  final String fanStatus;
}