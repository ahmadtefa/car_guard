import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../models/dashboard_state.dart';
import '../providers/voltage_delta_provider.dart';
import 'battery_voltage_card.dart';
import 'dashboard_gauges.dart';
import 'delta_style_gauge.dart';
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

  final device = ref.watch(deviceStatusProvider).value;

  final connected = device?.connected ?? false;
  final temperature = device?.temperatureData.engineTemperature ?? 0;
  final voltage = device?.batteryData.voltage ?? 0;

  // The live voltage difference shown by every dashboard style: the
  // module-reported value when the firmware streams one, otherwise the
  // locally computed delta; null renders an empty gauge.
  final delta = ref.watch(dashboardVoltageDeltaProvider);

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
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'racing',
            delta: delta,
            label: l.voltageDifference,
          ),
        ],
      );

    case 'sporty':
      return Column(
        children: [
          Row(
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
          ),
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'sporty',
            delta: delta,
            label: l.voltageDifference,
          ),
        ],
      );

    case 'segments':
      return Column(
        children: [
          Row(
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
          ),
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'segments',
            delta: delta,
            label: l.voltageDifference,
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
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'sweeper',
            delta: delta,
            label: l.voltageDifference,
          ),
        ],
      );

    case 'ring':
      return Column(
        children: [
          Row(
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
          ),
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'ring',
            delta: delta,
            label: l.voltageDifference,
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
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'led',
            delta: delta,
            label: l.voltageDifference,
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
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'needle',
            delta: delta,
            label: l.voltageDifference,
          ),
        ],
      );

    case 'orb':
      return Column(
        children: [
          Row(
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
          ),
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'orb',
            delta: delta,
            label: l.voltageDifference,
          ),
        ],
      );

    case 'combo':
      return Column(
        children: [
          Row(
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
          ),
          const SizedBox(height: AppSpacing.md),
          StyledDeltaGauge(
            styleName: 'combo',
            delta: delta,
            label: l.voltageDifference,
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
