import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// Reusable divider widget with consistent spacing.
class AppDivider extends StatelessWidget {
  /// Creates an application divider.
  const AppDivider({super.key, this.height = AppSpacing.md});

  /// The vertical spacing around the divider.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height),
      child: const Divider(),
    );
  }
}
