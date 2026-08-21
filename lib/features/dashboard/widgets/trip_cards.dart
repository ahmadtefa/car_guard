import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/widgets/secondary_button.dart';
import '../providers/trip_provider.dart';

/// Two side-by-side cards fed by the phone GPS: current vehicle speed
/// (km/h) and the resettable trip distance (km).
class TripCards extends ConsumerWidget {
  const TripCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider);
    final l = ref.watch(l10nProvider);

    final speedText =
        trip.hasFix ? trip.speedKmh.toStringAsFixed(0) : '--';
    final distanceText =
        trip.hasFix ? trip.distanceKm.toStringAsFixed(2) : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _TripCard(
                title: l.vehicleSpeed,
                value: speedText,
                unit: l.kmh,
                icon: Icons.speed_rounded,
                color: AppColors.neonCyan,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _TripCard(
                title: l.tripDistance,
                value: distanceText,
                unit: l.km,
                icon: Icons.route_rounded,
                color: AppColors.neonGreen,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        SecondaryButton(
          onPressed: trip.distanceKm > 0
              ? () => ref.read(tripProvider.notifier).resetTrip()
              : null,
          child: Text(l.resetTrip),
        ),

        // Friendly heads-up instead of silently dead cards.
        if (trip.denied || !trip.available)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              trip.denied ? l.locationDenied : l.gpsOff,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
            ),
          ),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: color),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
