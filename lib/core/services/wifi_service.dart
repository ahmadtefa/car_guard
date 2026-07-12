import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract contract for Wi-Fi infrastructure operations.
///
/// This service is intentionally isolated from UI and business logic.
/// Concrete implementations can be swapped later through Riverpod.
abstract class WiFiService {
  /// Initializes any internal Wi-Fi state required by the infrastructure layer.
  Future<bool> initialize();

  /// Connects to a Wi-Fi network using the provided credentials.
  Future<void> connect({required String ssid, String? password});

  /// Disconnects from the currently connected Wi-Fi network.
  Future<void> disconnect();

  /// Returns whether the device is currently connected to Wi-Fi.
  Future<bool> isConnected();
}

/// Default implementation for Wi-Fi infrastructure operations.
///
/// The current implementation is a placeholder to keep the architecture ready
/// for later device-specific integrations without coupling the app to them.
/// TODO: Replace this placeholder with a platform-specific Wi-Fi implementation.
class WiFiServiceImpl implements WiFiService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> connect({required String ssid, String? password}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isConnected() async => false;
}

/// Riverpod provider for exposing a Wi-Fi service implementation.
final wifiServiceProvider = Provider<WiFiService>((ref) => WiFiServiceImpl());
