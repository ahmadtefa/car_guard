import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// Reusable section header widget.
class SectionTitle extends StatelessWidget {
  /// Creates a section title widget.
  const SectionTitle({super.key, required this.title, this.subtitle});

  /// The main title text.
  final String title;

  /// Optional subtitle text.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            softWrap: true,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
