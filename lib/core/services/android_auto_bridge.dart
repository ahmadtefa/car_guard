import 'package:flutter/services.dart';

/// Publishes the live car status from the Flutter app to the native Android
/// Auto car UI (rendered through the Android for Cars App Library).
///
/// The native side persists the latest snapshot in `CarStatusStore`
/// (see `android/.../car/CarStatusStore.kt`), which `CarGuardCarAppService`
/// reads whenever it renders the car screen — on a real head unit or on the
/// Desktop Head Unit (DHU) while testing.
class AndroidAutoBridge {
  const AndroidAutoBridge._();

  static const MethodChannel _channel = MethodChannel('car_guard/car_status');

  /// Pushes the latest snapshot to the car UI.
  ///
  /// Values that are `null` are omitted so the car screen keeps showing
  /// nothing rather than misleading zeros. Safe to call on any platform:
  /// it silently does nothing where the native handler is unavailable
  /// (iOS, web, tests).
  static Future<void> publishStatus({
    required bool connected,
    double? engineTemperatureC,
    double? batteryVoltage,
    bool? coolantAvailable,
    bool? fanRunning,
  }) async {
    try {
      await _channel.invokeMethod<void>('publishStatus', <String, dynamic>{
        'connected': connected,
        if (engineTemperatureC != null) 'engineTemperatureC': engineTemperatureC,
        if (batteryVoltage != null) 'batteryVoltage': batteryVoltage,
        if (coolantAvailable != null) 'coolantAvailable': coolantAvailable,
        if (fanRunning != null) 'fanRunning': fanRunning,
      });
    } on MissingPluginException {
      // Platform without the native handler – ignore.
    } on PlatformException {
      // Native side rejected/failed the call – ignore.
    }
  }
}
