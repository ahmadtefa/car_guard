import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import 'base_dashboard_card.dart';

/// Displays whether the app is currently talking to the device.
class ConnectionStatusCard extends ConsumerWidget {
  /// Creates a connection status card.
  const ConnectionStatusCard({super.key, this.statusText = 'Disconnected'});

  /// Status token displayed in the card ('Connected'/'Disconnected').
  final String statusText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final connected = statusText == 'Connected';

    final color = connected ? AppColors.neonGreen : AppColors.neonRed;

    return BaseDashboardCard(
      title: l.connectionStatus,
      value: '',
      subtitle: connected ? l.streamingLive : l.waitingForDevice,
      statusText: '',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withAlpha((255 * 0.12).round()),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected
                  ? Icons.sensors_rounded
                  : Icons.sensors_off_rounded,
              size: 18,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              connected ? l.connected : l.disconnected,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
