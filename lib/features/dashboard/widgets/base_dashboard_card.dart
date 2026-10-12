import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/primary_card.dart';

/// A reusable, compact dashboard metric card.
///
/// Keep the metric title inside the same surface as its reading and gauge;
/// a second heading outside the card made the dashboard visually repetitive.
class BaseDashboardCard extends StatelessWidget {
  const BaseDashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.statusText,
    this.child,
  });

  final String title;
  final String value;
  final String subtitle;
  final String statusText;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PrimaryCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    softWrap: true,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 7, left: 8, right: 2),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.45),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (value.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: theme.textTheme.bodyMedium),
            ],
            if (child != null) ...[
              const SizedBox(height: AppSpacing.md),
              child!,
            ],
            if (statusText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                statusText,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
