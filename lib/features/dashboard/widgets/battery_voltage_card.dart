import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

/// A reusable placeholder widget for displaying battery voltage.
class BatteryVoltageCard extends StatelessWidget {
  /// Creates a battery voltage card.
  const BatteryVoltageCard({
    super.key,
    this.value = '--.-',
    this.unit = 'V',
    this.statusText = 'Unknown',
  });

  /// Optional placeholder value for the voltage display.
  final String value;

  /// Optional unit label for the voltage display.
  final String unit;

  /// Optional status label shown beneath the value.
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Battery Voltage',
      value: '$value $unit',
      subtitle: 'Waiting for voltage...',
      statusText: statusText,
    );
  }
}
