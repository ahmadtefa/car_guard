import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/secondary_button.dart';
import '../providers/trip_provider.dart';
import 'base_dashboard_card.dart';

/// GPS speed and trip distance cards fed by [tripProvider].
class TripCards extends ConsumerWidget {
  const TripCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider);

    final speedText =
        trip.hasFix ? '${trip.speedKmh.toStringAsFixed(0)} km/h' : '-- km/h';
    final distanceText =
        trip.hasFix ? '${trip.distanceKm.toStringAsFixed(2)} km' : '-- km';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BaseDashboardCard(
          title: 'Vehicle Speed',
          value: speedText,
          subtitle: 'From phone GPS',
          statusText: trip.hasFix ? 'Live' : 'Waiting for GPS...',
        ),

        const SizedBox(height: AppSpacing.md),

        BaseDashboardCard(
          title: 'Trip Distance',
          value: distanceText,
          subtitle: 'Total distance since reset',
          statusText: '',
          child: SecondaryButton(
            onPressed: trip.distanceKm > 0
                ? () => ref.read(tripProvider.notifier).resetTrip()
                : null,
            child: const Text('Reset Trip'),
          ),
        ),

        // Friendly heads-up instead of silently dead cards.
        if (trip.denied || !trip.available)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.denied
                      ? 'Location permission denied — speed tracking is off.'
                      : 'Location services are off — turn on GPS.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(tripProvider.notifier).start(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
