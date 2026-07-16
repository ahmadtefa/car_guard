// Strongly typed domain models for the ESP8266 communication layer.
class DeviceStatus {
  const DeviceStatus({
    required this.connected,
    required this.deviceId,
    required this.batteryData,
    required this.temperatureData,
    required this.coolantLevelData,
    required this.controlData,
    required this.lastUpdated,
  });

  final bool connected;
  final String deviceId;

  final BatteryData batteryData;
  final TemperatureData temperatureData;
  final CoolantLevelData coolantLevelData;
  final DeviceControlData controlData;

  final DateTime lastUpdated;

  factory DeviceStatus.disconnected() {
    return DeviceStatus(
      connected: false,
      deviceId: 'unknown',
      batteryData: const BatteryData(),
      temperatureData: const TemperatureData(),
      coolantLevelData: const CoolantLevelData(),
      controlData: const DeviceControlData(),
      lastUpdated: DateTime.now(),
    );
  }

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      connected: json['connected'] as bool? ?? false,
      deviceId: json['deviceId'] as String? ?? 'unknown',

      batteryData: BatteryData.fromJson(
        Map<String, dynamic>.from(json['batteryData'] ?? {}),
      ),

      temperatureData: TemperatureData.fromJson(
        Map<String, dynamic>.from(json['temperatureData'] ?? {}),
      ),

      coolantLevelData: CoolantLevelData.fromJson(
        Map<String, dynamic>.from(json['coolantLevelData'] ?? {}),
      ),

      controlData: DeviceControlData.fromJson(
        Map<String, dynamic>.from(json['controlData'] ?? {}),
      ),

      lastUpdated:
          DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'connected': connected,
      'deviceId': deviceId,
      'batteryData': batteryData.toJson(),
      'temperatureData': temperatureData.toJson(),
      'coolantLevelData': coolantLevelData.toJson(),
      'controlData': controlData.toJson(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}


class BatteryData {
  const BatteryData({
    this.voltage = 0.0,
    this.voltageDifference = 0.0,
  });

  final double voltage;
  final double voltageDifference;

  factory BatteryData.fromJson(Map<String, dynamic> json) {
    return BatteryData(
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      voltageDifference: (json['voltageDifference'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'voltage': voltage,
      'voltageDifference': voltageDifference,
    };
  }
}


class TemperatureData {
  const TemperatureData({
    this.engineTemperature = 0.0,
  });

  final double engineTemperature;

  factory TemperatureData.fromJson(Map<String, dynamic> json) {
    return TemperatureData(
      engineTemperature:
          (json['engineTemperature'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'engineTemperature': engineTemperature,
    };
  }
}


class CoolantLevelData {
  const CoolantLevelData({
    this.coolantAvailable = true,
  });

  final bool coolantAvailable;

  factory CoolantLevelData.fromJson(Map<String, dynamic> json) {
    return CoolantLevelData(
      coolantAvailable:
          json['coolantAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coolantAvailable': coolantAvailable,
    };
  }
}


class DeviceControlData {
  const DeviceControlData({
    this.fanRunning = false,
    this.buzzerActive = false,
  });

  final bool fanRunning;
  final bool buzzerActive;

  factory DeviceControlData.fromJson(Map<String, dynamic> json) {
    return DeviceControlData(
      fanRunning: json['fanRunning'] as bool? ?? false,
      buzzerActive: json['buzzerActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fanRunning': fanRunning,
      'buzzerActive': buzzerActive,
    };
  }
}