import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

/// Displays the voltage difference reported by the device.
class VoltageDifferenceCard extends StatelessWidget {
  const VoltageDifferenceCard({
    super.key,
    this.value = '--.- V',
    this.statusText = 'Unknown',
  });

  /// Voltage difference reading including its unit (e.g. `0.12 V`).
  final String value;

  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Voltage Difference',
      value: value,
      subtitle: 'Charging vs. resting delta',
      statusText: statusText,
    );
  }
}
