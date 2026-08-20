import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/widgets/spinning_icon.dart';
import 'base_dashboard_card.dart';

/// Shows whether the alternator is charging (voltage >= 13.0 V), with a
/// spinning gear while charging.
class AlternatorStatusCard extends ConsumerWidget {
  const AlternatorStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final device = ref.watch(deviceStatusProvider).value;

    final connected = device?.connected ?? false;
    final voltage = device?.batteryData.voltage ?? 0;

    final charging = connected && voltage >= 13.0;

    return BaseDashboardCard(
      title: l.alternator,
      value: '',
      subtitle: !connected
          ? l.waitingForDevice
          : charging
          ? l.chargingHealthy(voltage.toStringAsFixed(2))
          : l.notChargingV(voltage.toStringAsFixed(2)),
      statusText: '',
      child: Row(
        children: [
          SpinningIcon(
            icon: Icons.settings,
            spinning: charging,
            duration: const Duration(milliseconds: 1200),
            size: 30,
            color: charging ? AppColors.neonGreen : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (charging ? AppColors.neonGreen : AppColors.neonAmber)
                  .withAlpha((255 * 0.12).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              charging ? l.charging : l.notCharging,
              style: TextStyle(
                color: charging ? AppColors.neonGreen : AppColors.neonAmber,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
