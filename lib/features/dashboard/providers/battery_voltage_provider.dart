import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_status_provider.dart';

/// The live battery voltage shared by every dashboard style.
///
/// Keep this separate from [voltageDeltaProvider]: the latter is intentionally
/// a trend/difference value and must not be used for the primary voltage
/// reading.
final batteryVoltageProvider = Provider<double?>((ref) {
  final device = ref.watch(deviceStatusProvider).value;
  if (device == null || !device.connected) return null;
  final voltage = device.batteryData.voltage;
  return voltage.isFinite ? voltage : null;
});
