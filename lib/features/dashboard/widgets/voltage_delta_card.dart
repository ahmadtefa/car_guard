import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_l10n.dart';
import '../providers/voltage_delta_provider.dart';
import 'base_dashboard_card.dart';
import 'dashboard_gauges.dart';
import 'mini_gauges.dart';
import 'more_gauges.dart';

/// Shows the non-negative voltage difference using the selected dashboard
/// gauge style. Classic Cards keeps the original card and arc implementation.
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
    // Keep the UI defensive even if an older provider instance is still
    // alive during a hot reload or settings migration.
    final delta = ref.watch(voltageDeltaProvider)?.abs();

    final String valueText;
    final String statusText;

    if (delta == null) {
      valueText = '--.- V';
      statusText = l.collectingData;
    } else {
      valueText = '${delta.toStringAsFixed(2)} V';
      statusText = delta < 0.15 ? l.deltaStable : l.deltaRising;
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

    final reading = delta.abs();
    final percent = (reading / _gaugeScale).clamp(0.0, 1.0).toDouble();
    final onTap = () {};

    switch (styleName) {
      case 'racing':
        return RacingGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          warning: false,
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
          warning: false,
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
          accentColor: AppColors.neonMagenta,
          onTap: onTap,
        );

      case 'led':
        return LedStripGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          danger: false,
          onTap: onTap,
        );

      case 'needle':
        return NeedleMeterGauge(
          label: l.voltageDifference,
          value: reading,
          unit: 'V',
          percent: percent,
          danger: false,
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
  final magnitude = delta?.abs();
  if (magnitude == null) return AppColors.textSecondary;
  if (magnitude < 0.15) return AppColors.neonCyan;
  return AppColors.neonGreen;
}
