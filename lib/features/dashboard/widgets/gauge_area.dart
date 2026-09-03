import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../models/dashboard_state.dart';
import 'battery_voltage_card.dart';
import 'dashboard_gauges.dart';
import 'more_gauges.dart';
import 'readings_grid.dart';

/// Builds the live gauge pair for the currently selected dashboard
/// style. Shared by the dashboard and the fullscreen gauges page.
Widget buildGaugeArea(
  BuildContext context,
  WidgetRef ref, {
  required AppSettings settings,
  required DashboardState state,
  required AppL10n l,
  required void Function(String type) onOpenHud,
  bool fullscreen = false,
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
      // 'cards': the four headline readings as a 2x2 responsive grid
      // (temperature + voltage difference on the first row, GPS speed +
      // distance on the second), with the battery voltage card kept right
      // below it exactly as before.
      if (fullscreen) {
        // Fullscreen mode is exactly the four cards, filling the screen; the
        // battery card is a dashboard-only extra (its numbers are still one tap
        // away through the temp/volt HUD).
        return DashboardReadingsGrid(fullscreen: true, onOpenHud: onOpenHud);
      }

      return Column(
        children: [
          DashboardReadingsGrid(onOpenHud: onOpenHud),
          const SizedBox(height: AppSpacing.md),
          BatteryVoltageCard(
            value: state.batteryVoltage,
            statusText: connected ? l.liveReading : l.noData,
            voltage: connected ? voltage : null,
            lowValue: settings.minBatteryVoltage,
            highValue: settings.maxBatteryVoltage,
          ),
        ],
      );
  }
}
