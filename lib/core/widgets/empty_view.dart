import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';

/// Reusable empty state widget.
class EmptyView extends StatelessWidget {
  /// Creates an empty view.
  const EmptyView({super.key, this.message = AppStrings.emptyState, this.icon});

  /// Message displayed in the empty state.
  final String message;

  /// Optional icon for the empty state.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
