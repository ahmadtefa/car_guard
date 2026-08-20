import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/models/device_alert.dart';

/// Banner shown at the top of the dashboard while alerts are active.
///
/// Displays the most urgent alert prominently and mentions how many more are
/// firing behind it.
class AlertsBanner extends StatelessWidget {
  /// Creates an alerts banner; renders nothing when [alerts] is empty.
  const AlertsBanner({super.key, required this.alerts});

  /// Currently active alerts (unsorted is fine, the banner sorts them).
  final List<DeviceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final sorted = [...alerts]
      ..sort((a, b) => b.severity.rank.compareTo(a.severity.rank));
    final lead = sorted.first;

    final color = switch (lead.severity) {
      AlertSeverity.critical => AppColors.danger,
      AlertSeverity.warning => AppColors.warning,
      AlertSeverity.info => AppColors.textSecondary,
    };

    final icon = switch (lead.severity) {
      AlertSeverity.critical => Icons.warning_amber_rounded,
      AlertSeverity.warning => Icons.notification_important_rounded,
      AlertSeverity.info => Icons.info_outline_rounded,
    };

    return Card(
      color: color.withAlpha((255 * 0.12).round()),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: Padding(
        padding: AppSpacing.padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: color),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    lead.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (sorted.length > 1) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '+${sorted.length - 1} more alert'
                      '${sorted.length > 2 ? 's' : ''}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
