import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_state.dart';

final dashboardProvider =
    Provider<DashboardState>((ref) {
  return const DashboardState(
    connectionStatus: 'Disconnected',
    engineTemperature: '-- °C',
    batteryVoltage: '-- V',
    voltageDifference: '-- V',
    coolantLevel: '--',
  );
});