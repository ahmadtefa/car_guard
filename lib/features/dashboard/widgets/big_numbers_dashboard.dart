import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BigNumbersRow(
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
  }

  static String _format(double? value, {int fractionDigits = 0}) {
    if (value == null || !value.isFinite) return '--';
    return value.toStringAsFixed(fractionDigits);
  }
}

class _BigNumbersRow extends StatelessWidget {
  const _BigNumbersRow({required this.first, required this.second});

  static const double _minimumCardWidth = 150;

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.hasBoundedWidth &&
            constraints.maxWidth >=
                _minimumCardWidth * 2 + AppSpacing.md;

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
      },
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

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
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
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontSize: 46,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              unit,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
