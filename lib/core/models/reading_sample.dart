/// A single point-in-time capture of the live device readings.
class ReadingSample {
  const ReadingSample({
    required this.timestamp,
    required this.engineTemperature,
    required this.batteryVoltage,
  });

  final DateTime timestamp;
  final double engineTemperature;
  final double batteryVoltage;
}
