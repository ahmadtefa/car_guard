import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

class FanStatusCard extends StatelessWidget {
  const FanStatusCard({
    super.key,
    this.value = 'OFF',
    this.statusText = 'Unknown',
  });

  final String value;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Radiator Fan',
      value: value,
      subtitle: 'Cooling system fan status',
      statusText: statusText,
    );
  }
}