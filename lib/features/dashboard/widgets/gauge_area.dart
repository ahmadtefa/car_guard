import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/dashboard_state.dart';
import 'battery_voltage_card.dart';
import 'dashboard_gauges.dart';
import 'engine_temperature_card.dart';
import 'more_gauges.dart';
import 'voltage_delta_card.dart';

/// Builds the live gauge pair for the currently selected dashboard
/// style. Shared by the dashboard and the fullscreen gauges page.
Widget buildGaugeArea(
  BuildContext context,
  WidgetRef ref, {
  required AppSettings settings,
  required DashboardState state,
  required AppL10n l,
  required void Function(String type) onOpenHud,
}) {

  final settingsReady = ref.watch(
    settingsProvider.select((value) => value.value != null),
  );
  final device = settingsReady
      ? ref.watch(deviceStatusProvider).value
      : null;

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

  // Every non-card gauge renders a numeric double. Do not feed it a synthetic
  // zero while the source is disconnected; render explicit placeholders
  // instead so a real value can never look like a current zero.
  if (!connected) {
    return _UnavailableGaugeArea(l: l);
  }

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
            onTap: () => onOpenHud('temp'),
          ),
          const SizedBox(height: AppSpacing.md),
          RacingGauge(
            label: l.batteryVoltLabel,
            value: voltage,
            unit: 'V',
            percent: voltPercent,
            warning: voltWarning,
            onTap: () => onOpenHud('volt'),
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
              onTap: () => onOpenHud('temp'),
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
              onTap: () => onOpenHud('volt'),
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
              onTap: () => onOpenHud('temp'),
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
              onTap: () => onOpenHud('volt'),
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
            onTap: () => onOpenHud('temp'),
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
            onTap: () => onOpenHud('volt'),
          ),
        ],
      );

    case 'ring':
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: NeonRingGauge(
              label: l.engineTempLabel,
              value: temperature,
              unit: '°C',
              percent: tempPercent,
              danger: tempWarning,
              onTap: () => onOpenHud('temp'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: NeonRingGauge(
              label: l.batteryVoltLabel,
              value: voltage,
              unit: 'V',
              percent: voltPercent,
              danger: voltWarning,
              onTap: () => onOpenHud('volt'),
            ),
          ),
        ],
      );

    case 'led':
      return Column(
        children: [
          LedStripGauge(
            label: l.engineTempLabel,
            value: temperature,
            unit: '°C',
            percent: tempPercent,
            danger: tempWarning,
            onTap: () => onOpenHud('temp'),
          ),
          const SizedBox(height: AppSpacing.md),
          LedStripGauge(
            label: l.batteryVoltLabel,
            value: voltage,
            unit: 'V',
            percent: voltPercent,
            danger: voltWarning,
            onTap: () => onOpenHud('volt'),
          ),
        ],
      );

    case 'needle':
      return Column(
        children: [
          NeedleMeterGauge(
            label: l.engineTempLabel,
            value: temperature,
            unit: '°C',
            percent: tempPercent,
            danger: tempWarning,
            onTap: () => onOpenHud('temp'),
          ),
          const SizedBox(height: AppSpacing.md),
          NeedleMeterGauge(
            label: l.batteryVoltLabel,
            value: voltage,
            unit: 'V',
            percent: voltPercent,
            danger: voltWarning,
            onTap: () => onOpenHud('volt'),
          ),
        ],
      );

    case 'orb':
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LiquidOrbGauge(
              label: l.engineTempLabel,
              value: temperature,
              unit: '°C',
              percent: tempPercent,
              danger: tempWarning,
              onTap: () => onOpenHud('temp'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: LiquidOrbGauge(
              label: l.batteryVoltLabel,
              value: voltage,
              unit: 'V',
              percent: voltPercent,
              danger: voltWarning,
              onTap: () => onOpenHud('volt'),
            ),
          ),
        ],
      );

    case 'combo':
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DigitalClusterGauge(
              label: l.engineTempLabel,
              value: temperature,
              unit: '°C',
              percent: tempPercent,
              danger: tempWarning,
              onTap: () => onOpenHud('temp'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: DigitalClusterGauge(
              label: l.batteryVoltLabel,
              value: voltage,
              unit: 'V',
              percent: voltPercent,
              danger: voltWarning,
              onTap: () => onOpenHud('volt'),
            ),
          ),
        ],
      );

    default:
      return Column(
        children: [
          EngineTemperatureCard(
            value: state.engineTemperature,
            temperature: connected ? temperature : null,
            warnValue: settings.engineTempWarning,
            criticalValue: settings.engineTempCritical,
          ),
          const SizedBox(height: AppSpacing.md),
          BatteryVoltageCard(
            value: state.batteryVoltage,
            statusText: connected ? l.liveReading : l.noData,
            voltage: connected ? voltage : null,
            lowValue: settings.minBatteryVoltage,
            highValue: settings.maxBatteryVoltage,
          ),
          const SizedBox(height: AppSpacing.md),
          const VoltageDeltaCard(),
        ],
      );
  }
}

class _UnavailableGaugeArea extends StatelessWidget {
  const _UnavailableGaugeArea({required this.l});

  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UnavailableGaugeCard(label: l.engineTempLabel, unit: '°C'),
        const SizedBox(height: AppSpacing.md),
        _UnavailableGaugeCard(label: l.batteryVoltLabel, unit: 'V'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.realReadingsUnavailable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _UnavailableGaugeCard extends StatelessWidget {
  const _UnavailableGaugeCard({required this.label, required this.unit});

  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.textSecondary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: AppSpacing.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '-- $unit',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
