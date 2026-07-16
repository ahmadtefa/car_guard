import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

class CoolantLevelCard extends StatelessWidget {
  const CoolantLevelCard({
    super.key,
    this.title = 'Coolant Level',
    this.value = '--',
    this.statusText = 'Unknown',
  });

  final String title;
  final String value;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: title,
      value: value,
      subtitle: 'Coolant reservoir status',
      statusText: statusText,
    );
  }
}