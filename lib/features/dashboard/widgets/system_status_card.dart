import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/device_alert.dart';
import '../../../core/providers/device_status_provider.dart';
import '../providers/alerts_provider.dart';

/// Compact system status card — the twin of the fan/alternator row:
/// green "system OK" normally, or the most urgent active alert in
/// amber/red when something is wrong.
class SystemStatusCard extends ConsumerWidget {
  const SystemStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final alerts = ref.watch(alertsProvider).active;
    final device = ref.watch(deviceStatusProvider).value;

    final connected = device?.connected ?? false;
    final temperature = device?.temperatureData.engineTemperature;
    final voltage = device?.batteryData.voltage;

    // Highest severity wins.
    DeviceAlert? lead;
    for (final alert in alerts) {
      if (lead == null || alert.severity.rank > lead.severity.rank) {
        lead = alert;
      }
    }

    final Color color;
    final String text;
    final IconData icon;

    if (lead != null && lead.severity != AlertSeverity.info) {
      color = lead.severity == AlertSeverity.critical
          ? AppColors.neonRed
          : AppColors.neonAmber;
      text = lead.title;
      icon = lead.severity == AlertSeverity.critical
          ? Icons.warning_amber_rounded
          : Icons.error_outline_rounded;
    } else if (lead != null) {
      // Info-level alert (e.g. connection lost).
      color = AppColors.neonRed;
      text = lead.title;
      icon = Icons.sensors_off_rounded;
    } else if (!connected) {
      color = AppColors.neonRed;
      text = l.disconnected;
      icon = Icons.sensors_off_rounded;
    } else {
      color = AppColors.neonGreen;
      text = l.systemOk;
      icon = Icons.check_circle_rounded;
    }

    final summary = (temperature == null || voltage == null)
        ? '--'
        : '${temperature.toStringAsFixed(1)}°C | ${voltage.toStringAsFixed(2)}V';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              summary,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
