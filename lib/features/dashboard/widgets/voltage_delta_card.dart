import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_l10n.dart';
import '../providers/voltage_delta_provider.dart';
import 'base_dashboard_card.dart';
import 'mini_gauges.dart';

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
    final delta = ref.watch(voltageDeltaProvider);

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

    return _buildCardsGauge(
      l: l,
      delta: delta,
      valueText: valueText,
      statusText: statusText,
    );
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
