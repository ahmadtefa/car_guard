import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import 'base_dashboard_card.dart';

class BatteryVoltageCard extends ConsumerWidget {
  const BatteryVoltageCard({
    super.key,
    this.value = '--.- V',
    this.statusText = 'Unknown',
  });

  /// Voltage reading including its unit (e.g. `12.58 V`).
  final String value;

  final String statusText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    return BaseDashboardCard(
      title: l.batteryVoltage,
      value: value,
      subtitle: l.vehicleBatteryInfo,
      statusText: statusText == 'Unknown' ? l.unknown : statusText,
    );
  }
}
