import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_repository.dart';
import '../services/esp8266_repository.dart';
import '../services/storage_service.dart';


final esp8266RepositoryProvider = Provider<Esp8266Repository>((ref) {

  final repository = Esp8266Repository(
    host: '192.168.4.1',
    port: 81,
  );


  // Load user-saved IP asynchronously
  ref.read(storageServiceProvider).read('device_host').then((savedHost) {
    repository.connect(
      host: savedHost ?? '192.168.4.1',
      port: 81,
    );
  }).catchError((_) {
    repository.connect(
      host: '192.168.4.1',
      port: 81,
    );
  });


  ref.onDispose(() async {
    await repository.disconnect();
  });


  return repository;
});


final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {

  return ref.watch(esp8266RepositoryProvider);

});