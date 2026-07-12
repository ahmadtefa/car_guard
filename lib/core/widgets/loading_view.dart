import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../constants/app_spacing.dart';

/// Reusable loading state widget.
class LoadingView extends StatelessWidget {
  /// Creates a loading view.
  const LoadingView({super.key, this.message = AppStrings.loading});

  /// Message displayed alongside the indicator.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(message),
          ],
        ),
      ),
    );
  }
}
