import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_l10n.dart';
import 'base_dashboard_card.dart';
import 'mini_gauges.dart';

class EngineTemperatureCard extends ConsumerWidget {
  const EngineTemperatureCard({
    super.key,
    this.value = '-- °C',
    this.temperature,
    this.warnValue = 100,
    this.criticalValue = 110,
  });

  final String value;

  /// Raw reading for the arc gauge; null shows an empty track.
  final double? temperature;

  /// Warning threshold used to color the gauge zones.
  final double warnValue;

  /// Critical threshold — lights the gauge red.
  final double criticalValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final danger = temperature != null && temperature! >= criticalValue;

    return BaseDashboardCard(
      title: l.engineTemperature,
      value: danger ? '' : value,
      subtitle: l.coolantSensorInfo,
      statusText: value == '-- °C' ? l.noData : l.monitoring,
      child: Column(
        children: [
          MiniArcGauge(
            value: temperature,
            min: 40,
            max: 140,
            warnValue: warnValue,
            criticalValue: criticalValue,
            danger: danger,
          ),
          if (danger)
            Text(
              '⚠️ ${temperature!.toStringAsFixed(0)} °C',
              style: const TextStyle(
                color: AppColors.neonRed,
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
          ],
        ),
    );
  }
}
