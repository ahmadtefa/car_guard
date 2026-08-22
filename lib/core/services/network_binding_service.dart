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

  /// Current Android SDK level, 0 on non-Android platforms.
  static Future<int> androidSdkLevel() async {
    if (!_supported) return 0;

    try {
      return await _channel.invokeMethod<int>('androidSdkInt') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Requests an APP-SCOPED Wi-Fi link to the module network
  /// (WifiNetworkSpecifier, Android 10+). The request removes the INTERNET
  /// capability, so Android never reroutes the phone's other apps away from
  /// mobile data — the module stays reachable and 4G keeps working.
  static Future<bool> pairWithModuleWifi({
    required String ssid,
    String password = '',
  }) async {
    if (!_supported) return false;

    try {
      final ok = await _channel.invokeMethod<bool>(
        'pairModuleWifi',
        <String, String>{'ssid': ssid, 'password': password},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('WIFI PAIRING FAILED: $e');
      return false;
    }
  }

  /// Tears the app-scoped pairing down.
  static Future<void> unpairModuleWifi() async {
    if (!_supported) return;

    try {
      await _channel.invokeMethod<bool>('unpairModuleWifi');
    } catch (_) {}
  }
}
