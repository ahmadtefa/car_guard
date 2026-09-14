import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';

/// Minimal four-reading dashboard presentation: the values are the visual
/// focus and do not use gauges, arcs, bars, circles or decorative graphics.
class BigNumbersDashboard extends StatelessWidget {
  const BigNumbersDashboard({
    super.key,
    required this.temperature,
    required this.voltageDifference,
    required this.speed,
    required this.distance,
    required this.temperatureLabel,
    required this.voltageLabel,
    required this.speedLabel,
    required this.distanceLabel,
    required this.temperatureUnit,
    required this.voltageUnit,
    required this.speedUnit,
    required this.distanceUnit,
  });

  final double? temperature;
  final double? voltageDifference;
  final double? speed;
  final double? distance;
  final String temperatureLabel;
  final String voltageLabel;
  final String speedLabel;
  final String distanceLabel;
  final String temperatureUnit;
  final String voltageUnit;
  final String speedUnit;
  final String distanceUnit;

  // Two 170px cards plus the inter-card gap. Below this width, stacking keeps
  // the 46px value typography readable without horizontal overflow.
  static const double _twoColumnBreakpoint = 352;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentSizedBox = context.findAncestorWidgetOfExactType<SizedBox>();
        final parentConstrainedBox =
            context.findAncestorWidgetOfExactType<ConstrainedBox>();
        final explicitWidth = parentSizedBox?.width ??
            (parentConstrainedBox?.constraints.hasBoundedWidth == true
                ? parentConstrainedBox?.constraints.maxWidth
                : null);

        final availableWidth = explicitWidth ?? constraints.maxWidth;
        final sideBySide = availableWidth >= _twoColumnBreakpoint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BigNumbersRow(
              sideBySide: sideBySide,
              first: BigNumbersCard(
                label: temperatureLabel,
                value: _format(temperature),
                unit: temperatureUnit,
                accentColor: AppColors.neonAmber,
              ),
              second: BigNumbersCard(
                label: voltageLabel,
                value: _format(voltageDifference, fractionDigits: 2),
                unit: voltageUnit,
                accentColor: AppColors.neonCyan,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _BigNumbersRow(
              sideBySide: sideBySide,
              first: BigNumbersCard(
                label: speedLabel,
                value: _format(speed, fractionDigits: 0),
                unit: speedUnit,
                accentColor: AppColors.neonGreen,
              ),
              second: BigNumbersCard(
                label: distanceLabel,
                value: _format(distance, fractionDigits: 2),
                unit: distanceUnit,
                accentColor: const Color(0xFFC084FC),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _format(double? value, {int fractionDigits = 0}) {
    if (value == null || !value.isFinite) return '--';
    return value.toStringAsFixed(fractionDigits);
  }
}

class _BigNumbersRow extends StatelessWidget {
  const _BigNumbersRow({
    required this.first,
    required this.second,
    required this.sideBySide,
  });

  final Widget first;
  final Widget second;
  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: AppSpacing.md),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: second),
      ],
    );
  }
}

/// A premium automotive numeric card: the number is prominently styled in its
/// dedicated accent color with a subtle ambient glow, while the card surface
/// carries a quiet gradient and border matching the metric's identity.
class BigNumbersCard extends StatelessWidget {
  const BigNumbersCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.accentColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? colors.primary;

    final primaryTextColor = _effectiveTextColor(accent, isDark);

    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Color.alphaBlend(accent.withValues(alpha: 0.12), colors.surface),
              Color.alphaBlend(accent.withValues(alpha: 0.04), colors.surface),
            ]
          : [
              Color.alphaBlend(accent.withValues(alpha: 0.08), colors.surface),
              Color.alphaBlend(accent.withValues(alpha: 0.02), colors.surface),
            ],
    );

    final borderColor = isDark
        ? accent.withValues(alpha: 0.28)
        : accent.withValues(alpha: 0.22);

    final shadowColor = isDark
        ? accent.withValues(alpha: 0.10)
        : accent.withValues(alpha: 0.05);

    return Container(
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: AppRadius.large,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: primaryTextColor,
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    shadows: isDark
                        ? [
                            Shadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                unit,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _effectiveTextColor(Color accent, bool isDark) {
    if (isDark) return accent;
    final hsl = HSLColor.fromColor(accent);
    return hsl
        .withLightness((hsl.lightness * 0.45).clamp(0.24, 0.40))
        .withSaturation((hsl.saturation * 1.1).clamp(0.7, 1.0))
        .toColor();
  }
}
