import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';

/// Riverpod provider for exposing the connectivity infrastructure service contract.
///
/// This keeps network state access abstract and ready for future integration.
final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ref.watch(connectivityServiceProvider),
);

/// Streams the overall network availability.
///
/// Emits the current state first so listeners react immediately, then
/// follows the operating system connectivity changes. This is what lets the
/// app notice a WiFi drop instantly instead of waiting for socket timeouts.
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);

  yield await service.isConnected();

  yield* service.connectivityStream;
});
