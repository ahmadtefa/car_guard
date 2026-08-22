import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_service.dart';
import '../services/device_repository.dart';
import '../services/esp8266_repository.dart';
import '../services/storage_service.dart';
import 'connectivity_provider.dart';


final esp8266RepositoryProvider = Provider<Esp8266Repository>((ref) {

  final repository = Esp8266Repository(
    host: '192.168.4.1',
    port: 81,
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
  // service so Android keeps updating readings in the background. The
  // service intentionally stays up across temporary drops (it is what makes
  // automatic recovery work in the background too) and is only stopped on a
  // manual disconnect.
  final connectionEvents = repository.connectionStream.listen(
    (isConnected) {
      if (isConnected) {
        ref.read(backgroundConnectionServiceProvider).start();
      }
    },
  );

  ref.onDispose(connectionEvents.cancel);


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
