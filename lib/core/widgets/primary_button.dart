import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_radius.dart';

/// Reusable primary action button.
class PrimaryButton extends StatelessWidget {
  /// Creates a primary button.
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = AppDimensions.buttonHeight,
    this.padding,
    this.backgroundColor,
  });

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// The widget displayed inside the button.
  final Widget child;

  /// Minimum height for the button; wrapped labels may grow beyond it.
  final double height;

  /// Optional custom padding.
  final EdgeInsetsGeometry? padding;

  /// Optional custom background color.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: padding ?? const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          minimumSize: Size(0, height),
          backgroundColor: backgroundColor ?? AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        ),
        child: child,
      ),
    );
  }
}
