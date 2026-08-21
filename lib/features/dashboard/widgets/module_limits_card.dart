import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/services/device_models.dart';
import 'base_dashboard_card.dart';

/// Shows the alarm limits currently configured on the module itself,
/// as reported inside the live stream.
class ModuleLimitsCard extends ConsumerWidget {
  const ModuleLimitsCard({super.key});

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final ModuleLimits? limits =
        ref.watch(deviceStatusProvider).value?.moduleLimits;

    if (limits == null || limits.isEmpty) {
      return BaseDashboardCard(
        title: l.moduleLimits,
        value: '',
        subtitle: l.notReported,
        statusText: '',
      );
    }

    return BaseDashboardCard(
      title: l.moduleLimits,
      value: '',
      subtitle: l.moduleLimitsInfo,
      statusText: '',
      child: Column(
        children: [
          _row(
            l.alarmTempShort,
            limits.maxTemp == null ? '--' : '${limits.maxTemp!.toStringAsFixed(0)} °C',
          ),
          _row(
            l.fanOnShort,
            limits.fanOnTemp == null ? '--' : '${limits.fanOnTemp!.toStringAsFixed(0)} °C',
          ),
          _row(
            l.minVoltShort,
            limits.minVolt == null ? '--' : '${limits.minVolt!.toStringAsFixed(1)} V',
          ),
          _row(
            l.maxVoltShort,
            limits.maxVolt == null ? '--' : '${limits.maxVolt!.toStringAsFixed(1)} V',
          ),
        ],
      ),
    );
  }
}
