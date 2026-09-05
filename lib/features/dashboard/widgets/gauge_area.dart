import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/dashboard_state.dart';
import 'dashboard_gauges.dart';
import 'engine_temperature_card.dart';
import 'more_gauges.dart';
import 'trip_cards.dart';
import 'voltage_delta_card.dart';

/// Builds the four primary dashboard readings in their fixed order:
/// engine temperature, voltage difference, speed, then distance.
///
/// The selected dashboard style is still used for the temperature gauge. The
/// voltage-difference card and the phone GPS trip cards keep their existing
/// widgets/data sources; only their placement is centralized here so the
/// normal and fullscreen dashboards cannot drift apart.
Widget buildGaugeArea(
  BuildContext context,
  WidgetRef ref, {
  required AppSettings settings,
  required DashboardState state,
  required AppL10n l,
  required void Function(String type) onOpenHud,
  bool compact = false,
}) {
  final settingsReady = ref.watch(
    settingsProvider.select((value) => value.value != null),
  );
  final device = settingsReady
      ? ref.watch(deviceStatusProvider).value
      : null;

  final connected = device?.connected ?? false;
  final temperature = device?.temperatureData.engineTemperature ?? 0;
  final tempPercent = (temperature / 180).clamp(0.0, 1.0);
  final tempWarning = connected && temperature >= settings.engineTempCritical;

  // Never render a disconnected device as a synthetic zero. The two phone
  // GPS cards remain in the layout, but their own provider supplies '--' until
  // a real fix exists.
  if (!connected) {
    return _UnavailableGaugeArea(l: l, compact: compact);
  }

  final temperatureGauge = _buildTemperatureGauge(
    settings: settings,
    state: state,
    l: l,
    temperature: temperature,
    tempPercent: tempPercent,
    tempWarning: tempWarning,
    onOpenHud: onOpenHud,
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ResponsivePrimaryReadings(
        temperature: temperatureGauge,
        voltageDifference: const VoltageDeltaCard(),
      ),
      const SizedBox(height: AppSpacing.md),
      TripCards(showControls: !compact),
    ],
  );
}

/// Uses the same natural two-column/one-column behavior as the dashboard's
/// other responsive cards: the primary readings share a row only when the
/// available width can support both cards without compressing their content.
class _ResponsivePrimaryReadings extends StatelessWidget {
  const _ResponsivePrimaryReadings({
    required this.temperature,
    required this.voltageDifference,
  });

  final Widget temperature;
  final Widget voltageDifference;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 460;

        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              temperature,
              const SizedBox(height: AppSpacing.md),
              voltageDifference,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: temperature),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: voltageDifference),
          ],
        );
      },
    );
  }
}

/// Keeps the existing style picker meaningful while the second primary metric
/// is now the existing voltage-difference card instead of battery voltage.
Widget _buildTemperatureGauge({
  required AppSettings settings,
  required DashboardState state,
  required AppL10n l,
  required double temperature,
  required double tempPercent,
  required bool tempWarning,
  required void Function(String type) onOpenHud,
}) {
  switch (settings.dashboardStyleName) {
    case 'racing':
      return RacingGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        percent: tempPercent,
        warning: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    case 'sporty':
      return SportyGauge(
        label: l.engineTempLabel,
        value: temperature,
        min: 0,
        max: 180,
        redlineValue: settings.engineTempCritical,
        unit: '°C',
        warning: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    case 'segments':
      return SegmentedGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        activeCount: (tempPercent * 12).round(),
        danger: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    case 'sweeper':
      return AudiSweeperGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        percent: tempPercent,
        gradientColors: [
          AppColors.neonCyan,
          AppColors.neonAmber,
          AppColors.neonRed,
        ],
        accentColor: tempWarning
            ? AppColors.neonRed
            : AppColors.neonMagenta,
        onTap: () => onOpenHud('temp'),
      );

    case 'ring':
      return NeonRingGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        percent: tempPercent,
        danger: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    case 'led':
      return LedStripGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        percent: tempPercent,
        danger: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    case 'needle':
      return NeedleMeterGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        percent: tempPercent,
        danger: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    case 'orb':
      return LiquidOrbGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        percent: tempPercent,
        danger: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    case 'combo':
      return DigitalClusterGauge(
        label: l.engineTempLabel,
        value: temperature,
        unit: '°C',
        percent: tempPercent,
        danger: tempWarning,
        onTap: () => onOpenHud('temp'),
      );

    default:
      return EngineTemperatureCard(
        value: state.engineTemperature,
        temperature: temperature,
        warnValue: settings.engineTempWarning,
        criticalValue: settings.engineTempCritical,
      );
  }
}

class _UnavailableGaugeArea extends StatelessWidget {
  const _UnavailableGaugeArea({required this.l, required this.compact});

  final AppL10n l;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsivePrimaryReadings(
          temperature: _UnavailableGaugeCard(
            label: l.engineTempLabel,
            unit: '°C',
          ),
          voltageDifference: _UnavailableGaugeCard(
            label: l.voltageDifference,
            unit: 'V',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.realReadingsUnavailable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        TripCards(showControls: !compact),
      ],
    );
  }
}

class _UnavailableGaugeCard extends StatelessWidget {
  const _UnavailableGaugeCard({required this.label, required this.unit});

  final String label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.textSecondary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: AppSpacing.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '-- $unit',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
