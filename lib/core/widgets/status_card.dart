import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

/// Reusable card for presenting status-related information.
class StatusCard extends StatelessWidget {
  /// Creates a status card.
  const StatusCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.color,
  });

  /// The title shown above the value.
  final String title;

  /// The current value displayed in the card.
  final String value;

  /// Optional status icon.
  final IconData? icon;

  /// Optional accent color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? AppColors.primary;

    return Card(
      color: accentColor.withAlpha((255 * 0.08).round()),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: Padding(
        padding: AppSpacing.padding,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: accentColor),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
