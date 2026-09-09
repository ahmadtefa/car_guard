import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import 'base_dashboard_card.dart';
import 'dashboard_gauges.dart';
import 'mini_gauges.dart';
import 'more_gauges.dart';

/// Shows the signed voltage difference using the same card and gauge layout
/// as the engine-temperature reading. The presentation range starts at zero;
/// the signed reading remains unchanged in the card value and status text.
class VoltageDeltaCard extends ConsumerWidget {
  const VoltageDeltaCard({
    super.key,
    this.styleName = 'cards',
  });

  /// Uses the same persisted dashboard style as the temperature gauge.
  final String styleName;

  static const double _gaugeScale = 1.5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final device = ref.watch(deviceStatusProvider).value;
    final delta = device == null || !device.connected
        ? null
        : device.batteryData.voltageDifference;

    final String valueText;
    final String statusText;

    if (delta == null) {
      valueText = '--.- V';
      statusText = l.collectingData;
    } else {
      final sign = delta >= 0 ? '+' : '';

      valueText = '$sign${delta.toStringAsFixed(2)} V';

      if (delta.abs() < 0.15) {
        statusText = l.deltaStable;
      } else if (delta > 0) {
        statusText = l.deltaRising;
      } else {
        statusText = l.deltaFalling;
      }
    }

    return _buildGauge(
      l: l,
      delta: delta,
      valueText: valueText,
      statusText: statusText,
    );
  }

  Widget _buildGauge({
    required AppL10n l,
    required double? delta,
    required String valueText,
    required String statusText,
  }) {
    final card = _buildCardsGauge(
      l: l,
      delta: delta,
      valueText: valueText,
      statusText: statusText,
    );

    // The classic card is the exact Engine Temperature card structure. Keep
    // the empty card for a missing reading instead of presenting a synthetic
    // zero through one of the non-nullable style gauges.
    if (delta == null || styleName == 'cards') return card;

    final reading = delta;
    final percent = (reading / _gaugeScale).clamp(0.0, 1.0).toDouble();
    final negativeReading = reading < 0;
    final onTap = () {};

    switch (styleName) {
      case 'racing':
        return RacingGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          warning: negativeReading,
          onTap: onTap,
        );

      case 'sporty':
        return SportyGauge(
          label: l.voltageDifference,
          value: reading,
          min: 0,
          max: _gaugeScale,
          redlineValue: _gaugeScale,
          unit: 'V',
          warning: negativeReading,
          onTap: onTap,
        );

      case 'segments':
        return SegmentedGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          activeCount: (percent * 12).round(),
          danger: negativeReading,
          onTap: onTap,
        );

      case 'sweeper':
        return AudiSweeperGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          gradientColors: [
            AppColors.neonCyan,
            AppColors.neonAmber,
            AppColors.neonRed,
          ],
          accentColor: negativeReading
              ? AppColors.neonRed
              : AppColors.neonMagenta,
          onTap: onTap,
        );

      case 'ring':
        return NeonRingGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          danger: negativeReading,
          onTap: onTap,
        );

      case 'led':
        return LedStripGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          danger: negativeReading,
          onTap: onTap,
        );

      case 'needle':
        return NeedleMeterGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          danger: negativeReading,
          onTap: onTap,
        );

      case 'orb':
        return LiquidOrbGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          danger: negativeReading,
          onTap: onTap,
        );

      case 'combo':
        return DigitalClusterGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          danger: negativeReading,
          onTap: onTap,
        );

      default:
        return card;
    }
  }

  Widget _buildCardsGauge({
    required AppL10n l,
    required double? delta,
    required String valueText,
    required String statusText,
  }) {
    return BaseDashboardCard(
      title: l.voltageDifference,
      value: valueText,
      subtitle: l.chargingDeltaInfo,
      statusText: statusText,
      child: Column(
        children: [
          MiniArcGauge(
            value: delta,
            min: 0,
            max: _gaugeScale,
            warnValue: _gaugeScale,
            criticalValue: _gaugeScale,
            danger: false,
          ),
        ],
      ),
    );
  }
}

/// Kept for callers that want the accent color of the current trend.
Color deltaAccentColor(double? delta) {
  if (delta == null) return AppColors.textSecondary;
  if (delta.abs() < 0.15) return AppColors.neonCyan;
  return delta > 0 ? AppColors.neonGreen : AppColors.neonRed;
}
