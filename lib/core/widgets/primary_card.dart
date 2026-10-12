import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

/// Reusable card container for presenting grouped content.
///
/// The card deliberately uses the active theme rather than hard-coded colors,
/// so screens upgraded through this shared component stay consistent in RTL,
/// light mode and dark automotive mode.
class PrimaryCard extends StatelessWidget {
  const PrimaryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = color ?? theme.colorScheme.surface;
    final outline = theme.colorScheme.outline.withValues(
      alpha: isDark ? 0.68 : 0.82,
    );
    final accent = theme.colorScheme.primary;

    return Card(
      margin: margin ?? EdgeInsets.zero,
      elevation: elevation ?? 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.24 : 0.045),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: isDark ? 0.055 : 0.025),
                surface,
              ),
              surface,
            ],
          ),
        ),
        child: Padding(
          padding: padding ?? AppSpacing.padding,
          child: child,
        ),
      ),
    );
  }
}
