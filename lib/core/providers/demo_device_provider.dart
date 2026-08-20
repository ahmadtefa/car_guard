import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/demo_device_service.dart';

/// Exposes the demo simulator instance; disposed (and therefore stopped) as
/// soon as nothing watches it anymore.
final demoDeviceSimulatorProvider = Provider<DemoDeviceSimulator>((ref) {
  final simulator = DemoDeviceSimulator();

  ref.onDispose(simulator.dispose);

  return simulator;
});
