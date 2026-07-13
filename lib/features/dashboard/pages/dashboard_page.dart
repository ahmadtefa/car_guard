import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/battery_voltage_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/coolant_level_card.dart';
import '../widgets/engine_temperature_card.dart';
import '../widgets/voltage_difference_card.dart';

/// Composes the dashboard page from reusable dashboard widgets.
class DashboardPage extends ConsumerWidget {
  /// Creates a dashboard page.
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

return state.when(
  loading: () => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  ),
  error: (error, _) => Scaffold(
    body: Center(
      child: Text(error.toString()),
    ),
  ),
  data: (state) => Scaffold(
    appBar: AppBar(
      title: const Text('Car Guard'),
      centerTitle: false,
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: AppSpacing.padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConnectionStatusCard(
                      statusText: state.connectionStatus,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    EngineTemperatureCard(
                      value: state.engineTemperature,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    BatteryVoltageCard(
                      value: state.batteryVoltage,
                      statusText: state.connectionStatus,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VoltageDifferenceCard(
                      value: state.voltageDifference,
                      statusText: state.connectionStatus,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CoolantLevelCard(
                      value: state.coolantLevel,
                      statusText: state.connectionStatus,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  ),
);
  }
}
