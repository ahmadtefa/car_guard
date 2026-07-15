import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _connected = false;

  @override
  Future<bool> initialize() async {
    return true;
  }

  @override
  Future<void> connect({
    required String ssid,
    String? password,
  }) async {
    // سيتم تنفيذ الاتصال الحقيقي مع ESP8266 لاحقًا.
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<bool> isConnected() async {
    return _connected;
  }
}

final wifiServiceProvider = Provider<WiFiService>(
  (ref) => WiFiServiceImpl(),
);