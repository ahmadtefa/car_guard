import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_repository.dart';
import '../services/esp8266_repository.dart';

final esp8266RepositoryProvider = Provider<Esp8266Repository>((ref) {
  return Esp8266Repository(
    host: '192.168.4.1',
  );
});


final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return ref.watch(esp8266RepositoryProvider);
});