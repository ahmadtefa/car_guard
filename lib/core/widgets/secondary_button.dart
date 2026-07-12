import 'package:flutter/material.dart';

import '../constants/app_dimensions.dart';
import '../constants/app_radius.dart';

/// Reusable secondary action button.
class SecondaryButton extends StatelessWidget {
  /// Creates a secondary button.
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = AppDimensions.buttonHeight,
    this.padding,
  });

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// The widget displayed inside the button.
  final Widget child;

  /// Optional fixed height for the button.
  final double height;

  /// Optional custom padding.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
        child: child,
      ),
    );
  }
}
