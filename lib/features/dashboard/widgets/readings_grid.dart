import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/providers/effective_settings_provider.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/device_models.dart';
import '../providers/trip_provider.dart';
import '../providers/voltage_delta_provider.dart';
import 'mini_gauges.dart';
import 'reading_card.dart';
import 'voltage_delta_card.dart' show deltaAccentColor;

/// The four headline readings as a responsive grid:
///
/// ```text
/// ┌──────────────┐ ┌──────────────┐
/// │   الحرارة    │ │  فرق الجهد   │
/// └──────────────┘ └──────────────┘
/// ┌──────────────┐ ┌──────────────┐
/// │   السرعة     │ │   المسافة    │
/// └──────────────┘ └──────────────┘
/// ```
///
/// Two columns on a phone (degrading to a single column below ~300 dp so no
/// card is ever squeezed), and in [fullscreen] mode the rows share the height
/// they are given and the four cells sit side by side in landscape.
///
/// Data sources are unchanged: temperature and voltage difference come from the
/// module stream ([deviceStatusProvider] / the readings history), speed and
/// distance from the existing GPS trip provider. Nothing here invents a value
/// when its source is silent — the cell shows the app's "no data" text.
class DashboardReadingsGrid extends ConsumerWidget {
  const DashboardReadingsGrid({
    super.key,
    this.fullscreen = false,
    this.onOpenHud,
  });

  /// Big-screen mode: fills the height it is given and grows the type.
  final bool fullscreen;

  /// Opens the giant single-reading HUD, where the dashboard provides one.
  final void Function(String type)? onOpenHud;

  static const double _gap = AppSpacing.md;

  /// Narrowest width at which a second column is still honest about its text.
  static const double _twoColumnMinWidth = 300;

  /// Below this cell width the mini gauges are dropped: a 118 dp arc squeezed
  /// into a ~140 dp card reads worse than no arc at all, and the number — the
  /// thing that matters while driving — gets the room instead.
  static const double _gaugeMinCellWidth = 180;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);
    final settings = ref.watch(effectiveSettingsProvider);
    final device = ref.watch(deviceStatusProvider).value;
    final delta = ref.watch(voltageDeltaProvider);
    final trip = ref.watch(tripProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : size.width;
        final landscape = fullscreen && size.height < size.width;

        // The dashboard is always two cards side by side (temperature above
        // speed, voltage difference above distance) — on a phone and on a head
        // unit alike; only the *fullscreen* view spreads the four readings
        // across a landscape screen, because there the height is the scarce
        // resource. Below 300 dp a second column would squeeze the values out
        // of the card, so it degrades to one per row.
        final int columns = fullscreen
            ? (landscape ? 4 : 2)
            : (width >= _twoColumnMinWidth ? 2 : 1);

        final cellWidth = (width - _gap * (columns - 1)) / columns;
        final showGauge = cellWidth >= _gaugeMinCellWidth;

        final cells = <Widget>[
          _temperature(
            l: l,
            settings: settings,
            device: device,
            showGauge: showGauge,
          ),
          _voltageDelta(l: l, delta: delta, showGauge: showGauge),
          _speed(l: l, trip: trip),
          _distance(l: l, trip: trip),
        ];

        final rows = <List<Widget>>[];

        for (var i = 0; i < cells.length; i += columns) {
          rows.add(cells.skip(i).take(columns).toList());
        }

        final children = <Widget>[];

        for (var i = 0; i < rows.length; i++) {
          if (i > 0) {
            children.add(const SizedBox(height: _gap));
          }

          final row = Row(
            // In fullscreen the rows get their height from the parent, so the
            // two cards of a row stretch to it. In the scrolling dashboard the
            // height is not bounded, and each card takes exactly what its
            // content needs — no IntrinsicHeight pass, no overflow.
            crossAxisAlignment: fullscreen
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                if (j > 0) const SizedBox(width: _gap),
                Expanded(child: rows[i][j]),
              ],
            ],
          );

          children.add(fullscreen ? Expanded(child: row) : row);
        }

        return Column(children: children);
      },
    );
  }

  // ------------------------------------------------------------------
  // cells
  // ------------------------------------------------------------------

  Widget _temperature({
    required AppL10n l,
    required AppSettings settings,
    required DeviceStatus? device,
    required bool showGauge,
  }) {
    final connected = device?.connected ?? false;
    final double? temperature = connected
        ? device!.temperatureData.engineTemperature
        : null;

    final tempCritical =
        temperature != null && temperature >= settings.engineTempCritical;
    final tempWarning =
        temperature != null && temperature >= settings.engineTempWarning;

    return ReadingCard(
      title: l.engineTemperature,
      value: temperature == null ? '--' : temperature.toStringAsFixed(1),
      unit: '°C',
      statusText: temperature == null
          ? l.noData
          : (tempCritical || tempWarning)
          ? l.needsAttention
          : l.coolantSensorInfo,
      icon: Icons.thermostat_rounded,
      accent: tempCritical
          ? AppColors.neonRed
          : tempWarning
          ? AppColors.neonAmber
          : AppColors.neonMagenta,
      highlight: tempCritical,
      fullscreen: fullscreen,
      showGauge: showGauge,
      onTap: onOpenHud == null ? null : () => onOpenHud!('temp'),
      child: MiniArcGauge(
        value: temperature,
        min: 40,
        max: 140,
        warnValue: settings.engineTempWarning,
        criticalValue: settings.engineTempCritical,
        danger: tempCritical,
      ),
    );
  }

  Widget _voltageDelta({
    required AppL10n l,
    required double? delta,
    required bool showGauge,
  }) {
    return ReadingCard(
      title: l.voltageDifference,
      value: delta == null
          ? '--'
          : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)}',
      unit: 'V',
      statusText: delta == null
          ? l.collectingData
          : (delta.abs() < 0.15
                ? l.deltaStable
                : (delta > 0 ? l.deltaRising : l.deltaFalling)),
      icon: Icons.bolt_rounded,
      accent: deltaAccentColor(delta),
      fullscreen: fullscreen,
      showGauge: showGauge,
      child: DeltaGauge(delta: delta, scale: 1.5),
    );
  }

  Widget _speed({required AppL10n l, required TripState trip}) {
    return ReadingCard(
      title: l.vehicleSpeed,
      value: trip.hasFix ? trip.speedKmh.toStringAsFixed(0) : '--',
      unit: l.kmh,
      statusText: _gpsStatus(l, trip),
      icon: Icons.speed_rounded,
      accent: AppColors.neonCyan,
      highlight: !trip.available && !trip.denied,
      fullscreen: fullscreen,
    );
  }

  Widget _distance({required AppL10n l, required TripState trip}) {
    return ReadingCard(
      title: l.tripDistance,
      value: trip.hasFix ? trip.distanceKm.toStringAsFixed(2) : '--',
      unit: l.km,
      statusText: _gpsStatus(l, trip),
      icon: Icons.route_rounded,
      accent: AppColors.neonGreen,
      highlight: !trip.available && !trip.denied,
      fullscreen: fullscreen,
    );
  }

  /// Instead of two silently dead cells, the GPS problem is written inside the
  /// cards that depend on it (they used to share one hint line below them).
  static String _gpsStatus(AppL10n l, TripState trip) {
    if (trip.denied) {
      return l.locationDenied;
    }

    if (!trip.available) {
      return l.gpsOff;
    }

    return trip.hasFix ? l.liveReading : l.noData;
  }
}
