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

  Map<String, Object> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'engineTemperature': engineTemperature,
    'batteryVoltage': batteryVoltage,
  };

  static ReadingSample? fromJson(Object? value) {
    if (value is! Map) return null;
    final timestamp = DateTime.tryParse(value['timestamp']?.toString() ?? '');
    final temperature = (value['engineTemperature'] as num?)?.toDouble();
    final voltage = (value['batteryVoltage'] as num?)?.toDouble();
    if (timestamp == null ||
        temperature == null ||
        !temperature.isFinite ||
        voltage == null ||
        !voltage.isFinite) {
      return null;
    }
    return ReadingSample(
      timestamp: timestamp,
      engineTemperature: temperature,
      batteryVoltage: voltage,
    );
  }
}
