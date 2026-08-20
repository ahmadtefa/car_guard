import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/device_repository.dart';
import '../services/esp8266_repository.dart';
import '../services/storage_service.dart';


final esp8266RepositoryProvider = Provider<Esp8266Repository>((ref) {

  const defaults = AppSettings();

  final repository = Esp8266Repository(
    host: defaults.deviceHost,
    port: defaults.devicePort,
  );


  // Load the persisted settings and connect to the saved device address.
  ref.read(storageServiceProvider).read(AppSettings.storageKey).then((raw) {
    final settings = AppSettings.fromRaw(raw);

    repository.connect(
      host: settings.deviceHost,
      port: settings.devicePort,
    );
  }).catchError((_) {
    repository.connect(
      host: defaults.deviceHost,
      port: defaults.devicePort,
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
