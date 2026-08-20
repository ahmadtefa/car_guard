import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

class BatteryVoltageCard extends StatelessWidget {
  const BatteryVoltageCard({
    super.key,
    this.value = '--.- V',
    this.statusText = 'Unknown',
  });

  /// Voltage reading including its unit (e.g. `12.58 V`).
  final String value;

  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Battery Voltage',
      value: value,
      subtitle: 'Vehicle battery reading',
      statusText: statusText,
    );
  }
}
