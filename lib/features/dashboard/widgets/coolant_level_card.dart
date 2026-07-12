import 'package:flutter/material.dart';

import 'base_dashboard_card.dart';

/// A reusable placeholder widget for displaying coolant level information.
class CoolantLevelCard extends StatelessWidget {
  /// Creates a coolant level card.
  const CoolantLevelCard({
    super.key,
    this.title = 'Coolant Level',
    this.value = '--',
    this.statusText = 'Waiting for sensor...',
  });

  /// Title displayed above the placeholder value.
  final String title;

  /// Main placeholder value for the coolant level.
  final String value;

  /// Status label shown beneath the value.
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: title,
      value: value,
      subtitle: 'Waiting for measurement...',
      statusText: statusText,
    );
  }
}
