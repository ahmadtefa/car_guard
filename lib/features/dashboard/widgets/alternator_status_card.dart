import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/widgets/spinning_icon.dart';
import 'base_dashboard_card.dart';

/// Shows whether the alternator is charging (voltage >= 13.0 V), with a
/// spinning gear while charging — matching the original Kayan dashboard.
class AlternatorStatusCard extends ConsumerWidget {
  const AlternatorStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceStatusProvider).value;

    final connected = device?.connected ?? false;
    final voltage = device?.batteryData.voltage ?? 0;

    final charging = connected && voltage >= 13.0;

    final color = charging ? AppColors.neonGreen : AppColors.textSecondary;

    return BaseDashboardCard(
      title: 'Alternator',
      value: '',
      subtitle: charging
          ? 'Charging system healthy (${voltage.toStringAsFixed(2)} V)'
          : connected
          ? 'Not charging (${voltage.toStringAsFixed(2)} V)'
          : 'Waiting for device...',
      statusText: '',
      child: Row(
        children: [
          SpinningIcon(
            icon: Icons.settings,
            spinning: charging,
            duration: const Duration(milliseconds: 1200),
            size: 30,
            color: charging ? AppColors.neonGreen : color,
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (charging ? AppColors.neonGreen : AppColors.warning)
                  .withAlpha((255 * 0.12).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              charging ? 'Charging' : 'Not charging',
              style: TextStyle(
                color: charging ? AppColors.neonGreen : AppColors.warning,
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
