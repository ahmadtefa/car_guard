import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ota_service.dart';

/// Riverpod provider for exposing the OTA infrastructure service contract.
///
/// This allows future update flows to depend on the abstraction rather than a
/// concrete implementation.
/// TODO: Update this wiring when OTA update logic is implemented.
final otaProvider = Provider<OtaService>((ref) => ref.watch(otaServiceProvider));
