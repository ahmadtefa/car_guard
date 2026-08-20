import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import 'base_dashboard_card.dart';

/// Displays whether the app is currently talking to the device.
class ConnectionStatusCard extends StatelessWidget {
  /// Creates a connection status card.
  const ConnectionStatusCard({super.key, this.statusText = 'Disconnected'});

  /// Status text displayed in the card.
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final connected = statusText == 'Connected';

    final color = connected ? AppColors.success : AppColors.danger;

    return BaseDashboardCard(
      title: 'Connection Status',
      value: '',
      subtitle: connected
          ? 'Streaming live readings'
          : 'Waiting for device...',
      statusText: '',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withAlpha((255 * 0.12).round()),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected
                  ? Icons.sensors_rounded
                  : Icons.sensors_off_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              statusText,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
