import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/widgets/spinning_icon.dart';
import 'base_dashboard_card.dart';

/// Fan status card whose blade icon spins while the fan is running.
class FanStatusCard extends ConsumerWidget {
  const FanStatusCard({
    super.key,
    this.value = 'OFF',
    this.statusText = 'Unknown',
  });

  final String value;
  final String statusText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final running = value == 'ON';

    // Show the fan-on threshold reported by the module when available.
    final fanOnTemp = ref
        .watch(deviceStatusProvider)
        .value
        ?.moduleLimits
        .fanOnTemp;

    final subtitle = fanOnTemp == null
        ? l.fanSystemInfo
        : '${l.fanSystemInfo} • ${l.fanOnAt(fanOnTemp.toStringAsFixed(0))}';

    return BaseDashboardCard(
      title: l.radiatorFan,
      value: running ? l.on : l.off,
      subtitle: subtitle,
      statusText: statusText == 'Unknown' ? l.unknown : statusText,
      child: Row(
        children: [
          SpinningIcon(
            icon: Icons.air,
            spinning: running,
            size: 32,
            color: running ? AppColors.neonGreen : AppColors.neonAmber,
          ),
        ],
      ),
    );
  }
}
