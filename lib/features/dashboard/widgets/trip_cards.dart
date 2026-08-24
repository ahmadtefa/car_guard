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
              ? () => _confirmReset(context, ref, trip.distanceKm)
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

  /// Asks for confirmation before zeroing the odometer — the strings, the
  /// value and the notifier are captured up front so nothing touches
  /// [WidgetRef] after the await.
  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    double distanceKm,
  ) async {
    final l = ref.read(l10nProvider);
    final tripNotifier = ref.read(tripProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.resetTripConfirmTitle),
        content: Text(l.resetTripConfirmBody(distanceKm.toStringAsFixed(2))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.resetTrip),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      tripNotifier.resetTrip();
    }
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
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 34,
                          height: 1.0,
                        ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
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
