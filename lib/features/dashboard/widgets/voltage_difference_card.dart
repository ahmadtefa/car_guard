import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

/// A reusable placeholder widget for displaying voltage difference.
class VoltageDifferenceCard extends StatelessWidget {
  /// Creates a voltage difference card.
  const VoltageDifferenceCard({
    super.key,
    this.value = '--.-',
    this.unit = 'V',
    this.statusText = 'Unknown',
  });

  /// Optional placeholder value for the voltage difference display.
  final String value;

  /// Optional unit label for the voltage difference display.
  final String unit;

  /// Optional status label shown beneath the value.
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Voltage Difference',
      value: '$value $unit',
      subtitle: 'Waiting for measurement...',
      statusText: statusText,
    );
  }
}
