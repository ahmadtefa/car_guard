import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

class EngineTemperatureCard extends StatelessWidget {
  const EngineTemperatureCard({
    super.key,
    this.value = '-- °C',
  });

  final String value;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Engine Temperature',
      value: value,
      subtitle: 'Coolant temperature sensor',
      statusText: value == '-- °C'
          ? 'No data'
          : 'Monitoring',
    );
  }
}