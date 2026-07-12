import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_icons.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import 'secondary_button.dart';

/// Reusable error state widget.
class ErrorView extends StatelessWidget {
  /// Creates an error view.
  const ErrorView({
    super.key,
    this.message = AppStrings.errorState,
    this.onRetry,
  });

  /// Message displayed in the error state.
  final String message;

  /// Optional retry callback.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error, size: 48, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                onPressed: onRetry,
                child: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
