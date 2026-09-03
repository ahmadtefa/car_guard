import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/adaptive_text.dart';

/// One live reading in the dashboard grid: a title, a big value with its unit,
/// an optional status line and an optional gauge.
///
/// Every piece of text goes through [AdaptiveText], which sizes the glyphs to
/// the width the card actually got. That is what keeps a half-width card on a
/// small phone from cutting "المروحة لا تعمل" in half or throwing a RenderFlex
/// overflow, while the same widget renders comfortably large on a tablet and on
/// the head unit.
class ReadingCard extends StatelessWidget {
  const ReadingCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    this.statusText,
    this.icon,
    this.accent = AppColors.neonCyan,
    this.highlight = false,
    this.child,
    this.onTap,
    this.fullscreen = false,
    this.showGauge = true,
  });

  final String title;

  /// The formatted reading, without its unit (e.g. `92.4`).
  final String value;

  final String unit;

  /// Short explanation under the value (mode, trend, GPS hint…).
  final String? statusText;

  final IconData? icon;

  /// Accent colour for the value and the icon.
  final Color accent;

  /// Draws the warning border used for a critical reading.
  final bool highlight;

  /// Optional gauge painted inside the card (arc/bar), dropped in the tight
  /// cells automatically by the parent grid.
  final Widget? child;

  final VoidCallback? onTap;

  /// Fullscreen mode gets larger type and more vertical breathing room.
  final bool fullscreen;

  /// The grid turns this off for cells too narrow to hold a gauge honestly.
  final bool showGauge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final double gap = fullscreen ? AppSpacing.md : AppSpacing.sm;

    final titleStyle = (fullscreen
            ? theme.textTheme.titleMedium
            : theme.textTheme.titleSmall) ??
        const TextStyle(fontSize: 14);

    // Requested (maximum) sizes. AdaptiveText shrinks these per box; the
    // ceiling keeps a tablet/head-unit card from shouting.
    final valueStyle = TextStyle(
      fontSize: fullscreen ? 64 : 30,
      fontWeight: FontWeight.w900,
      height: 1.0,
      color: highlight ? AppColors.neonRed : accent,
      letterSpacing: fullscreen ? 1 : 0,
    );

    final statusStyle = (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12))
        .copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Card(
      // Zero margin: the grid owns the spacing, so the columns line up exactly.
      margin: EdgeInsets.zero,
      elevation: fullscreen ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(fullscreen ? 20 : 12),
        side: BorderSide(
          color: highlight
              ? AppColors.neonRed.withAlpha(190)
              : accent.withAlpha(fullscreen ? 90 : 46),
          width: highlight ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(fullscreen ? 20 : 12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(fullscreen ? 20 : 12),
          child: Padding(
            padding: EdgeInsets.all(fullscreen ? AppSpacing.lg : AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // In fullscreen the card is stretched by the grid, so the content
              // is centered in the space it was given; in the dashboard the card
              // is only as tall as its content.
              mainAxisSize: fullscreen ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: fullscreen
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: fullscreen ? 26 : 18,
                        color: highlight ? AppColors.neonRed : accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: AdaptiveText(
                        title,
                        style: titleStyle.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        minFontSize: fullscreen ? 13 : 10,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: gap),

                // Value + unit on one line: the unit is a separate Flexible so
                // a long unit string ("كم/س") can never push the number out.
                // Bottom-aligned rather than baseline-aligned: the value and
                // its unit are separate boxes here (each measured on its own),
                // and bottom alignment reads the same while staying safe for
                // any child that has no baseline to report.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: AdaptiveText(
                        value,
                        style: valueStyle,
                        maxLines: 1,
                        minFontSize: fullscreen ? 22 : 14,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: AdaptiveText(
                          unit,
                          style: TextStyle(
                            fontSize: fullscreen ? 22 : 12,
                            fontWeight: FontWeight.w700,
                            color: (highlight ? AppColors.neonRed : accent)
                                .withAlpha(210),
                          ),
                          maxLines: 1,
                          minFontSize: fullscreen ? 13 : 9,
                        ),
                      ),
                    ],
                  ],
                ),

                if (statusText != null && statusText!.isNotEmpty) ...[
                  SizedBox(height: gap * 0.5),
                  AdaptiveText(
                    statusText!,
                    style: statusStyle,
                    maxLines: 2,
                    minFontSize: fullscreen ? 12 : 9,
                  ),
                ],

                if (child != null && showGauge) ...[
                  SizedBox(height: gap),
                  child!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
