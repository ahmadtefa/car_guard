import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

/// Reusable card container for presenting grouped content.
class PrimaryCard extends StatelessWidget {
  /// Creates a primary card.
  const PrimaryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.color,
  });

  /// The content displayed inside the card.
  final Widget child;

  /// Optional padding for the content.
  final EdgeInsetsGeometry? padding;

  /// Optional margin around the card.
  final EdgeInsetsGeometry? margin;

  /// Optional elevation of the card.
  final double? elevation;

  /// Optional card color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin ?? EdgeInsets.zero,
      elevation: elevation ?? 1,
      color: color ?? Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      child: Padding(
        padding: padding ?? AppSpacing.padding,
        child: child,
      ),
    );
  }
}
