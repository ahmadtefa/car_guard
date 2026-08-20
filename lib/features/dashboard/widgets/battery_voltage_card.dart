import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import 'base_dashboard_card.dart';
import 'mini_gauges.dart';

class BatteryVoltageCard extends ConsumerWidget {
  const BatteryVoltageCard({
    super.key,
    this.value = '--.- V',
    this.statusText = 'Unknown',
    this.voltage,
    this.lowValue = 12.0,
    this.highValue = 14.8,
  });

  /// Voltage reading including its unit (e.g. `12.58 V`).
  final String value;

  final String statusText;

  /// Raw reading for the bar gauge; null shows an empty track.
  final double? voltage;

  final double lowValue;
  final double highValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    return BaseDashboardCard(
      title: l.batteryVoltage,
      value: value,
      subtitle: l.vehicleBatteryInfo,
      statusText: statusText == 'Unknown' ? l.unknown : statusText,
      child: MiniVoltBarGauge(
        value: voltage,
        min: 10,
        max: 16,
        lowValue: lowValue,
        highValue: highValue,
      ),
    );
  }
}
