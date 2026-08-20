import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/alerts_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/readings_history_provider.dart';
import '../widgets/alerts_banner.dart';
import '../widgets/battery_voltage_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/coolant_level_card.dart';
import '../widgets/device_controls_card.dart';
import '../widgets/engine_temperature_card.dart';
import '../widgets/fan_status_card.dart';
import '../widgets/reading_chart_card.dart';
import '../widgets/voltage_difference_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final activeAlerts = ref.watch(alertsProvider).active;
    final history = ref.watch(readingsHistoryProvider);
    final demoEnabled =
        ref.watch(settingsProvider).value?.demoModeEnabled ?? false;

    final connected = state.connectionStatus == 'Connected';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Car Guard'),
            if (demoEnabled) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha((255 * 0.15).round()),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'DEMO',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.warning),
                ),
              ),
            ],
          ],
        ),
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

                const SizedBox(height: AppSpacing.xl),

                ReadingChartCard(
                  title: 'Engine Temperature',
                  values: history
                      .map((sample) => sample.engineTemperature)
                      .toList(),
                  unit: '°C',
                  color: AppColors.danger,
                ),

                const SizedBox(height: AppSpacing.md),

                ReadingChartCard(
                  title: 'Battery Voltage',
                  values: history
                      .map((sample) => sample.batteryVoltage)
                      .toList(),
                  unit: 'V',
                  color: AppColors.success,
                ),

                const SizedBox(height: AppSpacing.md),

                const DeviceControlsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
