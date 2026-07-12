import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/primary_card.dart';
import '../../../core/widgets/section_title.dart';

/// A reusable layout wrapper for dashboard cards.
class BaseDashboardCard extends StatelessWidget {
  /// Creates a reusable dashboard card shell.
  const BaseDashboardCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.statusText,
    this.child,
  });

  /// Title displayed above the card content.
  final String title;

  /// Primary value shown in the card.
  final String value;

  /// Subtitle displayed beneath the primary value.
  final String subtitle;

  /// Status label shown beneath the subtitle.
  final String statusText;

  /// Optional custom child content inserted before the status text.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title),
        PrimaryCard(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (value.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (child != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    child!,
                  ],
                  if (statusText.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
