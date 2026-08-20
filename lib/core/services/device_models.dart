// Strongly typed domain models for the ESP8266 communication layer.
/// Alarm limits reported by the module inside its live stream.
///
/// Every field is nullable: the firmware may omit values, in which case the
/// app keeps its locally configured thresholds.
class ModuleLimits {
  const ModuleLimits({
    this.maxTemp,
    this.fanOnTemp,
    this.minVolt,
    this.maxVolt,
    this.offset,
  });

  final double? maxTemp;
  final double? fanOnTemp;
  final double? minVolt;
  final double? maxVolt;
  final double? offset;

  /// True when the module did not report any limit.
  bool get isEmpty =>
      maxTemp == null &&
      fanOnTemp == null &&
      minVolt == null &&
      maxVolt == null &&
      offset == null;

  factory ModuleLimits.fromJson(Map<String, dynamic> json) {
    return ModuleLimits(
      maxTemp: (json['maxTemp'] as num?)?.toDouble(),
      fanOnTemp: (json['fanOnTemp'] as num?)?.toDouble(),
      minVolt: (json['minVolt'] as num?)?.toDouble(),
      maxVolt: (json['maxVolt'] as num?)?.toDouble(),
      offset: (json['offset'] as num?)?.toDouble(),
    );
  }
}

class DeviceStatus {
  const DeviceStatus({
    required this.connected,
    required this.deviceId,
    required this.batteryData,
    required this.temperatureData,
    required this.coolantLevelData,
    required this.controlData,
    required this.lastUpdated,
    this.moduleLimits = const ModuleLimits(),
  });

  final bool connected;
  final String deviceId;

  final BatteryData batteryData;
  final TemperatureData temperatureData;
  final CoolantLevelData coolantLevelData;
  final DeviceControlData controlData;

  final DateTime lastUpdated;

  /// Limits reported alongside the reading, when the firmware sends them.
  final ModuleLimits moduleLimits;

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

      moduleLimits: ModuleLimits.fromJson(
        Map<String, dynamic>.from(json),
      ),
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
      'maxTemp': moduleLimits.maxTemp,
      'fanOnTemp': moduleLimits.fanOnTemp,
      'minVolt': moduleLimits.minVolt,
      'maxVolt': moduleLimits.maxVolt,
      'offset': moduleLimits.offset,
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


/// Settings stored on the ESP8266 module itself, loaded via `/getallsettings`.
class DeviceModuleSettings {
  const DeviceModuleSettings({
    this.maxTemp = 95.0,
    this.fanOnTemp = 85.0,
    this.minVolt = 12.0,
    this.maxVolt = 15.0,
    this.offset = 0.0,
    this.r1 = 2155.0,
    this.r2 = 390.0,
    this.voltCalib = 0.9724,
    this.sensorPullUp = 4700.0,
    this.installDate = '',
    this.serial = '',
  });

  /// Alarm temperature (°C) configured on the module.
  final double maxTemp;

  /// Temperature (°C) at which the module turns the fan on.
  final double fanOnTemp;

  /// Minimum battery voltage (V) configured on the module.
  final double minVolt;

  /// Maximum battery voltage (V) configured on the module.
  final double maxVolt;

  /// Temperature reading calibration offset (±°C).
  final double offset;

  /// Voltage divider resistor R1 (ohm).
  final double r1;

  /// Voltage divider resistor R2 (ohm).
  final double r2;

  /// Voltage calibration factor.
  final double voltCalib;

  /// Temperature sensor pull-up resistor (ohm).
  final double sensorPullUp;

  /// Module first-run date (yyyy-mm-dd) as reported by the firmware.
  final String installDate;

  /// Module serial number.
  final String serial;

  DeviceModuleSettings copyWith({
    double? maxTemp,
    double? fanOnTemp,
    double? minVolt,
    double? maxVolt,
    double? offset,
    double? r1,
    double? r2,
    double? voltCalib,
    double? sensorPullUp,
    String? installDate,
  }) {
    return DeviceModuleSettings(
      maxTemp: maxTemp ?? this.maxTemp,
      fanOnTemp: fanOnTemp ?? this.fanOnTemp,
      minVolt: minVolt ?? this.minVolt,
      maxVolt: maxVolt ?? this.maxVolt,
      offset: offset ?? this.offset,
      r1: r1 ?? this.r1,
      r2: r2 ?? this.r2,
      voltCalib: voltCalib ?? this.voltCalib,
      sensorPullUp: sensorPullUp ?? this.sensorPullUp,
      installDate: installDate ?? this.installDate,
      serial: serial,
    );
  }

  factory DeviceModuleSettings.fromJson(Map<String, dynamic> json) {
    return DeviceModuleSettings(
      maxTemp: (json['maxTemp'] as num?)?.toDouble() ?? 95.0,
      fanOnTemp: (json['fanOnTemp'] as num?)?.toDouble() ?? 85.0,
      minVolt: (json['minVolt'] as num?)?.toDouble() ?? 12.0,
      maxVolt: (json['maxVolt'] as num?)?.toDouble() ?? 15.0,
      offset: (json['offset'] as num?)?.toDouble() ?? 0.0,
      r1: (json['r1'] as num?)?.toDouble() ?? 2155.0,
      r2: (json['r2'] as num?)?.toDouble() ?? 390.0,
      voltCalib: (json['voltCalib'] as num?)?.toDouble() ?? 0.9724,
      sensorPullUp: (json['sensorPullUp'] as num?)?.toDouble() ?? 4700.0,
      installDate: json['installDate'] as String? ?? '',
      serial: json['serial'] as String? ?? '',
    );
  }
}
