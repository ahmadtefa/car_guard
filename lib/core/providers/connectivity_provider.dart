import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';

/// Riverpod provider for exposing the connectivity infrastructure service contract.
///
/// This keeps network state access abstract and ready for future integration.
/// TODO: Update this wiring when a real connectivity implementation is added.
final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ref.watch(connectivityServiceProvider),
);
