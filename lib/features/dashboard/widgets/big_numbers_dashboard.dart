import 'package:flutter/material.dart';

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
        // Evaluate the breakpoint once at the dashboard boundary. This keeps
        // the decision tied to the actual available dashboard width rather
        // than to a nested row that may receive loose constraints from a
        // parent layout.
        final sideBySide =
            constraints.hasBoundedWidth &&
            constraints.maxWidth >= _twoColumnBreakpoint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BigNumbersRow(
              sideBySide: sideBySide,
              first: BigNumbersCard(
                label: temperatureLabel,
                value: _format(temperature),
                unit: temperatureUnit,
              ),
              second: BigNumbersCard(
                label: voltageLabel,
                value: _format(voltageDifference, fractionDigits: 2),
                unit: voltageUnit,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _BigNumbersRow(
              sideBySide: sideBySide,
              first: BigNumbersCard(
                label: speedLabel,
                value: _format(speed, fractionDigits: 0),
                unit: speedUnit,
              ),
              second: BigNumbersCard(
                label: distanceLabel,
                value: _format(distance, fractionDigits: 2),
                unit: distanceUnit,
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

/// A deliberately quiet card: the number is large, while the label and unit
/// stay secondary so the four readings remain easy to scan at a glance.
class BigNumbersCard extends StatelessWidget {
  const BigNumbersCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final panelColor = theme.brightness == Brightness.dark
        ? Color.alphaBlend(
            Colors.white.withAlpha((255 * 0.06).round()),
            colors.surface,
          )
        : colors.surfaceContainerLow;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: panelColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.large,
        side: BorderSide(
          color: colors.outlineVariant.withAlpha((255 * 0.55).round()),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
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
                      color: colors.onSurface,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      height: 1,
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
      ),
    );
  }
}
