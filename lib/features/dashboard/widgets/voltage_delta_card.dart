import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../providers/voltage_delta_provider.dart';
import 'base_dashboard_card.dart';
import 'delta_style_gauge.dart';
import 'mini_gauges.dart';

/// Shows the live voltage difference — the module-reported value when the
/// firmware streams one, otherwise the change over the last ~90 seconds —
/// on a center-zero differential gauge: green to the right while charging,
/// red to the left while dropping.
///
/// Style selection is shared with the temperature gauge: the classic
/// 'cards' style keeps the original [DeltaGauge] card, while every other
/// dashboard style delegates to the definitive [StyledDeltaGauge].
class VoltageDeltaCard extends ConsumerWidget {
  const VoltageDeltaCard({
    super.key,
    this.styleName = 'cards',
  });

  /// Uses the same persisted dashboard style as the temperature gauge.
  final String styleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    // Definitive data source: module-reported difference when the firmware
    // streams one, otherwise the locally computed live delta; null (empty)
    // until either exists — never a synthetic 0.00.
    final delta = ref.watch(dashboardVoltageDeltaProvider);

    if (styleName != 'cards' &&
        AppSettings.dashboardStyleNames.contains(styleName)) {
      return StyledDeltaGauge(
        styleName: styleName,
        delta: delta,
        label: l.voltageDifference,
      );
    }

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

    return BaseDashboardCard(
      title: l.voltageDifference,
      value: valueText,
      subtitle: l.chargingDeltaInfo,
      statusText: statusText,
      child: DeltaGauge(
        delta: delta,
        scale: 1.5,
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
