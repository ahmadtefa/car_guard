import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../providers/alerts_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/alerts_banner.dart';
import '../widgets/battery_voltage_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/coolant_level_card.dart';
import '../widgets/engine_temperature_card.dart';
import '../widgets/fan_status_card.dart';
import '../widgets/voltage_difference_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final activeAlerts = ref.watch(alertsProvider).active;
    final connected = state.connectionStatus == 'Connected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Guard'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
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
                if (activeAlerts.isNotEmpty) ...[
                  AlertsBanner(alerts: activeAlerts),
                  const SizedBox(height: AppSpacing.md),
                ],

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
                  statusText: connected ? 'Live reading' : 'No data',
                ),

                const SizedBox(height: AppSpacing.md),

                VoltageDifferenceCard(
                  value: state.voltageDifference,
                  statusText: connected ? 'Live reading' : 'No data',
                ),

                const SizedBox(height: AppSpacing.md),

                CoolantLevelCard(
                  value: state.coolantLevel,
                  statusText: state.coolantLevel == 'Low'
                      ? 'Needs attention'
                      : 'Normal',
                ),

                const SizedBox(height: AppSpacing.md),

                FanStatusCard(
                  value: state.fanStatus,
                  statusText: connected ? 'Live reading' : 'No data',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
