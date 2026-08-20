import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/providers/effective_settings_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/dashboard_state.dart';
import '../providers/alerts_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/readings_history_provider.dart';
import '../widgets/alerts_banner.dart';
import '../widgets/alternator_status_card.dart';
import '../widgets/battery_voltage_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/dashboard_gauges.dart';
import '../widgets/device_controls_card.dart';
import '../widgets/engine_temperature_card.dart';
import '../widgets/fan_status_card.dart';
import '../widgets/fullscreen_hud_page.dart';
import '../widgets/module_limits_card.dart';
import '../widgets/reading_chart_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  void _openHud(BuildContext context, String type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullscreenHudPage(type: type),
      ),
    );
  }

  void _showStylePicker(BuildContext context, WidgetRef ref, AppL10n l) {
    final settings =
        ref.read(settingsProvider).value ?? const AppSettings();

    final options = <(String, IconData, String)>[
      ('cards', Icons.dashboard_outlined, l.styleCards),
      ('racing', Icons.speed, l.styleRacing),
      ('sporty', Icons.donut_large_outlined, l.styleSporty),
      ('segments', Icons.view_week_outlined, l.styleSegments),
      ('sweeper', Icons.linear_scale_outlined, l.styleSweeper),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l.dashboardStyle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              for (final (name, icon, label) in options)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  trailing:
                      settings.dashboardStyleName == name
                      ? const Icon(Icons.check_circle)
                      : null,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .save(
                          (ref.read(settingsProvider).value ??
                                  const AppSettings())
                              .copyWith(dashboardStyleName: name),
                        );

                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGaugeArea(
    BuildContext context,
    WidgetRef ref, {
    required AppSettings settings,
    required DashboardState state,
    required AppL10n l,
  }) {
    final device = ref.watch(deviceStatusProvider).value;

    final connected = device?.connected ?? false;
    final temperature = device?.temperatureData.engineTemperature ?? 0;
    final voltage = device?.batteryData.voltage ?? 0;

    final tempPercent = (temperature / 180).clamp(0.0, 1.0);
    final voltPercent = ((voltage - 10) / 6).clamp(0.0, 1.0);

    final tempWarning = connected && temperature >= settings.engineTempCritical;
    final voltWarning =
        connected &&
        (voltage <= settings.minBatteryVoltage ||
            voltage > settings.maxBatteryVoltage);

    switch (settings.dashboardStyleName) {
      case 'racing':
        return Column(
          children: [
            RacingGauge(
              label: l.engineTempLabel,
              value: temperature,
              unit: '°C',
              percent: tempPercent,
              warning: tempWarning,
              onTap: () => _openHud(context, 'temp'),
            ),
            const SizedBox(height: AppSpacing.md),
            RacingGauge(
              label: l.batteryVoltLabel,
              value: voltage,
              unit: 'V',
              percent: voltPercent,
              warning: voltWarning,
              onTap: () => _openHud(context, 'volt'),
            ),
          ],
        );

      case 'sporty':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SportyGauge(
                label: l.engineTempLabel,
                value: temperature,
                min: 0,
                max: 180,
                redlineValue: settings.engineTempCritical,
                unit: '°C',
                warning: tempWarning,
                onTap: () => _openHud(context, 'temp'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SportyGauge(
                label: l.batteryVoltLabel,
                value: voltage,
                min: 10,
                max: 16,
                redlineValue: settings.maxBatteryVoltage,
                unit: 'V',
                warning: voltWarning,
                onTap: () => _openHud(context, 'volt'),
              ),
            ),
          ],
        );

      case 'segments':
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SegmentedGauge(
                label: l.engineTempLabel,
                value: temperature,
                unit: '°C',
                activeCount: (tempPercent * 12).round(),
                danger: tempWarning,
                onTap: () => _openHud(context, 'temp'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SegmentedGauge(
                label: l.batteryVoltLabel,
                value: voltage,
                unit: 'V',
                activeCount: (voltPercent * 12).round(),
                danger: voltWarning,
                onTap: () => _openHud(context, 'volt'),
              ),
            ),
          ],
        );

      case 'sweeper':
        return Column(
          children: [
            AudiSweeperGauge(
              label: l.engineTempLabel,
              value: temperature,
              unit: '°C',
              percent: tempPercent,
              gradientColors: [
                AppColors.neonCyan,
                AppColors.neonAmber,
                AppColors.neonRed,
              ],
              accentColor: tempWarning
                  ? AppColors.neonRed
                  : AppColors.neonMagenta,
              onTap: () => _openHud(context, 'temp'),
            ),
            const SizedBox(height: AppSpacing.md),
            AudiSweeperGauge(
              label: l.batteryVoltLabel,
              value: voltage,
              unit: 'V',
              percent: voltPercent,
              gradientColors: [
                AppColors.neonRed,
                AppColors.neonGreen,
                AppColors.neonGreen,
              ],
              accentColor: voltWarning
                  ? AppColors.neonRed
                  : AppColors.neonGreen,
              onTap: () => _openHud(context, 'volt'),
            ),
          ],
        );

      default:
        return Column(
          children: [
            EngineTemperatureCard(value: state.engineTemperature),
            const SizedBox(height: AppSpacing.md),
            BatteryVoltageCard(
              value: state.batteryVoltage,
              statusText: connected ? l.liveReading : l.noData,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final activeAlerts = ref.watch(alertsProvider).active;
    final history = ref.watch(readingsHistoryProvider);

    final l = ref.watch(l10nProvider);

    final local = ref.watch(settingsProvider).value ?? const AppSettings();
    // Thresholds may be overridden by limits reported by the module.
    final settings = ref.watch(effectiveSettingsProvider);

    final demoEnabled = local.demoModeEnabled;
    final connected = state.connectionStatus == 'Connected';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.appName),
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
            tooltip: l.language,
            icon: Text(
              local.languageName == 'ar' ? 'EN' : 'ع',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              ref.read(settingsProvider.notifier).save(
                local.copyWith(
                  languageName: local.languageName == 'ar' ? 'en' : 'ar',
                ),
              );
            },
          ),
          IconButton(
            tooltip: l.dashboardStyle,
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => _showStylePicker(context, ref, l),
          ),
          IconButton(
            tooltip: l.settings,
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
        label: Text(l.deviceConnection),
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

                ConnectionStatusCard(statusText: state.connectionStatus),

                const SizedBox(height: AppSpacing.md),

                _buildGaugeArea(
                  context,
                  ref,
                  settings: settings,
                  state: state,
                  l: l,
                ),

                const SizedBox(height: AppSpacing.xs),

                Center(
                  child: Text(
                    '${l.lastUpdated}: ${state.lastUpdated}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                FanStatusCard(
                  value: state.fanStatus,
                  statusText: connected ? l.liveReading : l.noData,
                ),

                const SizedBox(height: AppSpacing.md),

                const AlternatorStatusCard(),

                const SizedBox(height: AppSpacing.md),

                const ModuleLimitsCard(),

                const SizedBox(height: AppSpacing.xl),

                ReadingChartCard(
                  title: l.engineTemperature,
                  values: history
                      .map((sample) => sample.engineTemperature)
                      .toList(),
                  unit: '°C',
                  color: AppColors.danger,
                ),

                const SizedBox(height: AppSpacing.md),

                ReadingChartCard(
                  title: l.batteryVoltage,
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
