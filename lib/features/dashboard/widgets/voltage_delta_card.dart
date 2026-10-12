import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import '../../settings/providers/settings_provider.dart';
import 'base_dashboard_card.dart';
import 'dashboard_gauges.dart';
import 'mini_gauges.dart';
import 'more_gauges.dart';
import 'premium_needle_gauge.dart';

/// Displays the live battery voltage with the selected dashboard gauge style.
/// The historical class name is retained to avoid breaking existing imports.
class VoltageDeltaCard extends ConsumerWidget {
  const VoltageDeltaCard({super.key, this.styleName = 'cards'});

  final String styleName;

  static const double _minimumVoltage = 10;
  static const double _maximumVoltage = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final device = ref.watch(deviceStatusProvider).value;
    final settings = ref.watch(settingsProvider).value;
    final double? voltage =
        device?.connected == true ? device!.batteryData.voltage : null;
    final ModuleLimits? limits =
        device?.connected == true ? device!.moduleLimits : null;
    final lowValue = limits?.minVolt ?? settings?.minBatteryVoltage ?? 12.0;
    final highValue = limits?.maxVolt ?? settings?.maxBatteryVoltage ?? 14.8;
    final warning = voltage != null &&
        (voltage < lowValue || voltage > highValue);
    final valueText =
        voltage == null ? '--.- V' : '\${voltage.toStringAsFixed(2)} V';
    final statusText = voltage == null
        ? l.collectingData
        : warning
            ? (voltage < lowValue ? l.batteryLowTitle : l.batteryHighTitle)
            : l.normal;

    if (voltage == null) {
      return BaseDashboardCard(
        title: l.batteryVoltage,
        value: '--.- V',
        subtitle: l.vehicleBatteryInfo,
        statusText: l.collectingData,
        child: MiniVoltBarGauge(
          value: null,
          min: _minimumVoltage,
          max: _maximumVoltage,
          lowValue: lowValue,
          highValue: highValue,
        ),
      );
    }

    if (styleName == 'cards') {
      return BaseDashboardCard(
        title: l.batteryVoltage,
        value: valueText,
        subtitle: l.vehicleBatteryInfo,
        statusText: statusText,
        child: MiniVoltBarGauge(
          value: voltage,
          min: _minimumVoltage,
          max: _maximumVoltage,
          lowValue: lowValue,
          highValue: highValue,
        ),
      );
    }

    void onTap() {}

    final percent = voltage == null
        ? 0.0
        : ((voltage - _minimumVoltage) /
                (_maximumVoltage - _minimumVoltage))
            .clamp(0.0, 1.0)
            .toDouble();

    switch (styleName) {
      case 'premium':
        return PremiumNeedleGauge(
          title: l.batteryVoltLabel,
          value: voltage,
          unit: 'V',
          min: _minimumVoltage,
          max: _maximumVoltage,
          warning: warning,
          onTap: onTap,
        );
      case 'racing':
        return RacingGauge(
          label: l.batteryVoltLabel,
          value: voltage,
          unit: 'V',
          percent: percent,
          warning: warning,
          onTap: onTap,
        );
      case 'sporty':
        return SportyGauge(
          label: l.batteryVoltLabel,
          value: voltage ?? 0,
          min: _minimumVoltage,
          max: _maximumVoltage,
          redlineValue: highValue,
          unit: 'V',
          warning: warning,
          onTap: onTap,
        );
      case 'sweeper':
        return AudiSweeperGauge(
          label: l.batteryVoltLabel,
          value: voltage ?? 0,
          unit: 'V',
          percent: percent,
          gradientColors: const [
            AppColors.neonCyan,
            AppColors.neonGreen,
            AppColors.neonAmber,
            AppColors.neonRed,
          ],
          accentColor: warning ? AppColors.neonRed : AppColors.neonCyan,
          onTap: onTap,
        );
      case 'led':
        return LedStripGauge(
          label: l.batteryVoltLabel,
          value: voltage ?? 0,
          unit: 'V',
          percent: percent,
          danger: warning,
          onTap: onTap,
        );
      case 'needle':
        return NeedleMeterGauge(
          label: l.batteryVoltLabel,
          value: voltage ?? 0,
          unit: 'V',
          percent: percent,
          danger: warning,
        );
      default:
        return BaseDashboardCard(
          title: l.batteryVoltage,
          value: valueText,
          subtitle: l.vehicleBatteryInfo,
          statusText: statusText,
          child: MiniVoltBarGauge(
            value: voltage,
            min: _minimumVoltage,
            max: _maximumVoltage,
            lowValue: lowValue,
            highValue: highValue,
          ),
        );
    }
  }
}

/// Kept for callers that need a voltage status accent.
Color deltaAccentColor(double? voltage) {
  if (voltage == null) return AppColors.textSecondary;
  if (voltage < 12.0 || voltage > 14.8) return AppColors.neonRed;
  return AppColors.neonGreen;
}
