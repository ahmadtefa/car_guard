/// Strongly typed domain models for the ESP8266 communication layer.
///
/// These models are intentionally isolated from UI and business logic so they
/// can be reused by repositories, providers, and future features.
class DeviceStatus {
  const DeviceStatus({
    required this.connected,
    required this.deviceId,
    required this.sensorData,
    required this.batteryData,
    required this.temperatureData,
    required this.coolantLevelData,
    required this.lastUpdated,
  });

  /// Whether the device is currently reachable.
  final bool connected;

  /// The identifier reported by the device.
  final String deviceId;

  /// Sensor values reported by the device.
  final SensorData sensorData;

  /// Battery state reported by the device.
  final BatteryData batteryData;

  /// Temperature state reported by the device.
  final TemperatureData temperatureData;

  /// Coolant level state reported by the device.
  final CoolantLevelData coolantLevelData;

  /// Timestamp of the most recent update.
  final DateTime lastUpdated;

  /// Creates a disconnected placeholder status.
  factory DeviceStatus.disconnected() {
    return DeviceStatus(
      connected: false,
      deviceId: 'unknown',
      sensorData: const SensorData(),
      batteryData: const BatteryData(),
      temperatureData: const TemperatureData(),
      coolantLevelData: const CoolantLevelData(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Parses a JSON payload into a strongly typed status model.
  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      connected: json['connected'] as bool? ?? false,
      deviceId: json['deviceId'] as String? ?? 'unknown',
      sensorData: SensorData.fromJson(
        Map<String, dynamic>.from(json['sensorData'] ?? {}),
      ),
      batteryData: BatteryData.fromJson(
        Map<String, dynamic>.from(json['batteryData'] ?? {}),
      ),
      temperatureData: TemperatureData.fromJson(
        Map<String, dynamic>.from(json['temperatureData'] ?? {}),
      ),
      coolantLevelData: CoolantLevelData.fromJson(
        Map<String, dynamic>.from(json['coolantLevelData'] ?? {}),
      ),
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Converts the model back to JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'connected': connected,
      'deviceId': deviceId,
      'sensorData': sensorData.toJson(),
      'batteryData': batteryData.toJson(),
      'temperatureData': temperatureData.toJson(),
      'coolantLevelData': coolantLevelData.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Sensor data reported by the device.
class SensorData {
  const SensorData({
    this.speed = 0.0,
    this.rpm = 0,
    this.fuelLevel = 0.0,
  });

  final double speed;
  final int rpm;
  final double fuelLevel;

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      rpm: json['rpm'] as int? ?? 0,
      fuelLevel: (json['fuelLevel'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'speed': speed,
      'rpm': rpm,
      'fuelLevel': fuelLevel,
    };
  }
}

/// Battery state reported by the device.
class BatteryData {
  const BatteryData({
    this.voltage = 0.0,
    this.percentage = 0.0,
    this.charging = false,
  });

  final double voltage;
  final double percentage;
  final bool charging;

  factory BatteryData.fromJson(Map<String, dynamic> json) {
    return BatteryData(
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      charging: json['charging'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'voltage': voltage,
      'percentage': percentage,
      'charging': charging,
    };
  }
}

/// Temperature values reported by the device.
class TemperatureData {
  const TemperatureData({
    this.engineTemperature = 0.0,
    this.coolantTemperature = 0.0,
  });

  final double engineTemperature;
  final double coolantTemperature;

  factory TemperatureData.fromJson(Map<String, dynamic> json) {
    return TemperatureData(
      engineTemperature: (json['engineTemperature'] as num?)?.toDouble() ?? 0.0,
      coolantTemperature: (json['coolantTemperature'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'engineTemperature': engineTemperature,
      'coolantTemperature': coolantTemperature,
    };
  }
}

/// Coolant level state reported by the device.
class CoolantLevelData {
  const CoolantLevelData({
    this.levelPercent = 0.0,
    this.lowWarning = false,
  });

  final double levelPercent;
  final bool lowWarning;

  factory CoolantLevelData.fromJson(Map<String, dynamic> json) {
    return CoolantLevelData(
      levelPercent: (json['levelPercent'] as num?)?.toDouble() ?? 0.0,
      lowWarning: json['lowWarning'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'levelPercent': levelPercent,
      'lowWarning': lowWarning,
    };
  }
}
