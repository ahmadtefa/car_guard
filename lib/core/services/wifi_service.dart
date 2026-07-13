import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wifi_iot/wifi_iot.dart';

abstract class WiFiService {
  Future<bool> initialize();

  Future<void> connect({
    required String ssid,
    String? password,
  });

  Future<void> disconnect();

  Future<bool> isConnected();
}

class WiFiServiceImpl implements WiFiService {
  @override
  Future<bool> initialize() async {
    return WiFiForIoTPlugin.isEnabled();
  }

  @override
  Future<void> connect({
    required String ssid,
    String? password,
  }) async {
    await WiFiForIoTPlugin.connect(
      ssid,
      password: password,
      security: NetworkSecurity.WPA,
      joinOnce: false,
    );
  }

  @override
  Future<void> disconnect() async {
    await WiFiForIoTPlugin.disconnect();
  }

  @override
  Future<bool> isConnected() async {
    return WiFiForIoTPlugin.isConnected();
  }
}

final wifiServiceProvider = Provider<WiFiService>(
  (ref) => WiFiServiceImpl(),
);