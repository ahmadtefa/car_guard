import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/background_service.dart';
import '../services/device_repository.dart';
import '../services/esp8266_repository.dart';
import '../services/storage_service.dart';
import 'connectivity_provider.dart';


final esp8266RepositoryProvider = Provider<Esp8266Repository>((ref) {

  const defaults = AppSettings();

  final repository = Esp8266Repository(
    host: defaults.deviceHost,
    port: defaults.devicePort,
  );


  // React immediately to operating system network changes: when WiFi is
  // turned off the device socket never receives a close event, so the drop
  // has to be applied from here; when a network comes back we reconnect.
  ref.listen<AsyncValue<bool>>(
    connectivityStatusProvider,
    (previous, next) {
      next.whenData((isOnline) {
        if (isOnline) {
          repository.handleNetworkAvailable();
        } else {
          repository.handleNetworkLost();
        }
      });
    },
  );


  // While a device connection is alive, promote the process to a foreground
  // service so Android keeps updating readings in the background.
  final connectionEvents = repository.connectionStream.listen(
    (isConnected) {
      if (isConnected) {
        ref.read(backgroundConnectionServiceProvider).start();
      }
    },
  );

  ref.onDispose(connectionEvents.cancel);


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
