import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/wifi_service.dart';

/// Riverpod provider for exposing the Wi-Fi infrastructure service contract.
///
/// This keeps the dependency graph aligned with the service abstraction and
/// allows implementations to be swapped without touching callers.
/// TODO: Update this wiring when a platform-specific Wi-Fi implementation is added.
final wifiProvider = Provider<WiFiService>((ref) => ref.watch(wifiServiceProvider));
