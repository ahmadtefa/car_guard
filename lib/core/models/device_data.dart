/// DeviceData model created per user specification.
class DeviceData {
  final double temperature;
  final double voltage;
  final double voltageDifference;
  final double coolantLevel;
  final bool fanState;

  const DeviceData({
    required this.temperature,
    required this.voltage,
    required this.voltageDifference,
    required this.coolantLevel,
    required this.fanState,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    Object? t = json['temperature'];
    Object? v = json['voltage'];
    Object? vd = json['voltageDifference'];
    Object? cl = json['coolantLevel'];
    Object? fs = json['fanState'];

    if (t is! num) {
      throw FormatException('temperature is not a number');
    }
    if (v is! num) {
      throw FormatException('voltage is not a number');
    }
    if (vd is! num) {
      throw FormatException('voltageDifference is not a number');
    }
    if (cl is! num) {
      throw FormatException('coolantLevel is not a number');
    }

    bool parseFanState(Object? value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true' || lower == '1') return true;
        if (lower == 'false' || lower == '0') return false;
      }
      throw FormatException('fanState is not a boolean-like value');
    }

    return DeviceData(
      temperature: t.toDouble(),
      voltage: v.toDouble(),
      voltageDifference: vd.toDouble(),
      coolantLevel: cl.toDouble(),
      fanState: parseFanState(fs),
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'voltage': voltage,
        'voltageDifference': voltageDifference,
        'coolantLevel': coolantLevel,
        'fanState': fanState,
      };

  DeviceData copyWith({
    double? temperature,
    double? voltage,
    double? voltageDifference,
    double? coolantLevel,
    bool? fanState,
  }) {
    return DeviceData(
      temperature: temperature ?? this.temperature,
      voltage: voltage ?? this.voltage,
      voltageDifference: voltageDifference ?? this.voltageDifference,
      coolantLevel: coolantLevel ?? this.coolantLevel,
      fanState: fanState ?? this.fanState,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DeviceData &&
            other.temperature == temperature &&
            other.voltage == voltage &&
            other.voltageDifference == voltageDifference &&
            other.coolantLevel == coolantLevel &&
            other.fanState == fanState);
  }

  @override
  int get hashCode => Object.hash(
        temperature,
        voltage,
        voltageDifference,
        coolantLevel,
        fanState,
      );
}
