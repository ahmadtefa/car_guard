import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

/// A reusable placeholder widget for displaying engine temperature.
class EngineTemperatureCard extends StatelessWidget {
  /// Creates an engine temperature card.
  const EngineTemperatureCard({super.key, this.value = '-- °C'});

  /// Value shown in the card.
  final String value;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Engine Temperature',
      value: value,
      subtitle: 'Waiting for temperature...',
      statusText: 'Unknown',
    );
  }
}
