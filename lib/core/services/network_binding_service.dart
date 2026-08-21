import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-only bridge that pins the app's traffic to the Car Guard module
/// Wi-Fi network while the rest of the phone keeps using mobile data.
///
/// Why: the module's access point serves no internet, so Android either
/// keeps the phone's default route on the dead Wi-Fi (internet dies) or
/// steers app sockets to 4G (module becomes unreachable). Binding this
/// process to the Wi-Fi transport fixes both sides at once.
class NetworkBindingService {
  NetworkBindingService._();

  static const MethodChannel _channel =
      MethodChannel('com.kayan.carguard/network');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Binds all app traffic to the connected Wi-Fi network.
  /// Returns false when there is no Wi-Fi network to bind to (harmless).
  static Future<bool> bindToModuleWifi() async {
    if (!_supported) return false;

    try {
      final ok = await _channel.invokeMethod<bool>('bindToWifi');
      return ok ?? false;
    } catch (e) {
      debugPrint('WIFI BIND FAILED: $e');
      return false;
    }
  }

  /// Releases the binding so the app follows the system default network.
  static Future<void> bindToDefault() async {
    if (!_supported) return;

    try {
      await _channel.invokeMethod<bool>('bindToDefault');
    } catch (_) {
      // Best-effort: the OS also drops the binding when Wi-Fi disconnects.
    }
  }
}
