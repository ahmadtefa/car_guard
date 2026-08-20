import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import 'base_dashboard_card.dart';

/// Displays the voltage difference reported by the device.
class VoltageDifferenceCard extends ConsumerWidget {
  const VoltageDifferenceCard({
    super.key,
    this.value = '--.- V',
    this.statusText = 'Unknown',
  });

  /// Voltage difference reading including its unit (e.g. `0.12 V`).
  final String value;

  final String statusText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    return BaseDashboardCard(
      title: l.voltageDifference,
      value: value,
      subtitle: l.chargingDeltaInfo,
      statusText: statusText == 'Unknown' ? l.unknown : statusText,
    );
  }
}
