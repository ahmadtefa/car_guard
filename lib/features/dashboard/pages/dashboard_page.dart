import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/battery_voltage_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/coolant_level_card.dart';
import '../widgets/engine_temperature_card.dart';
import '../widgets/fan_status_card.dart';
import '../widgets/trip_cards.dart';
import '../widgets/voltage_difference_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Guard'),
        centerTitle: false,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/connection');
        },
        icon: const Icon(Icons.wifi),
        label: const Text('Connection'),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppSpacing.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConnectionStatusCard(
                  statusText: state.connectionStatus,
                ),

                const SizedBox(height: AppSpacing.md),

                const TripCards(),

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

                const SizedBox(height: AppSpacing.md),

                FanStatusCard(
                  value: state.fanStatus,
                  statusText: state.connectionStatus,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}