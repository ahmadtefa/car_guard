
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

abstract class OtaService {
  Future<bool> checkForUpdate();

  Future<void> downloadUpdate();

  Future<void> installUpdate();

  Future<void> rollback();
}

class OtaServiceImpl implements OtaService {
  static const String _updateUrl = 'http://192.168.4.1/update';

  @override
  Future<bool> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(_updateUrl));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> downloadUpdate() async {
    // OTA firmware upload will be implemented with ESP8266 firmware integration.
  }

  @override
  Future<void> installUpdate() async {
    // Installation is handled by the ESP8266 after upload.
  }

  @override
  Future<void> rollback() async {
    throw UnsupportedError(
      'Rollback is not supported by ESP8266 OTA.',
    );
  }
}

final otaServiceProvider = Provider<OtaService>(
  (ref) => OtaServiceImpl(),
);