import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import 'base_dashboard_card.dart';

/// A reusable placeholder widget for displaying connection status.
class ConnectionStatusCard extends StatelessWidget {
  /// Creates a connection status card.
  const ConnectionStatusCard({super.key, this.statusText = 'Disconnected'});

  /// Status text displayed in the card.
  final String statusText;

  @override
  Widget build(BuildContext context) {
    return BaseDashboardCard(
      title: 'Connection Status',
      value: '',
      subtitle: 'Waiting for device...',
      statusText: '',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          statusText,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}
