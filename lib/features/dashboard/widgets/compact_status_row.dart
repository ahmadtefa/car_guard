import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/widgets/spinning_icon.dart';
import '../../license/providers/license_provider.dart';
import '../../settings/providers/settings_provider.dart';

/// Single compact row replacing the old fan and alternator cards:
/// just an icon and a short status for each, nothing else.
class FanAlternatorRow extends ConsumerWidget {
  const FanAlternatorRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final settingsReady = ref.watch(
      settingsProvider.select((value) => value.value != null),
    );
    final demoEnabled = ref.watch(
      settingsProvider.select((value) => value.value?.demoModeEnabled ?? false),
    );
    final licenseAuthorized = ref.watch(licenseAuthorizationProvider);
    final dataAccessAllowed =
        settingsReady && (demoEnabled || licenseAuthorized);
    final device = dataAccessAllowed
        ? ref.watch(deviceStatusProvider).value
        : null;

    final connected = device?.connected ?? false;
    final fanOn = device?.controlData.fanRunning ?? false;
    final voltage = device?.batteryData.voltage ?? 0;

    final charging = connected && voltage >= 13.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            SpinningIcon(
              icon: Icons.air,
              spinning: fanOn,
              size: 18,
              color: fanOn ? AppColors.neonGreen : AppColors.neonAmber,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '${l.fanShort}: ${fanOn ? l.on : l.off}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            SpinningIcon(
              icon: Icons.settings,
              spinning: charging,
              duration: const Duration(milliseconds: 1200),
              size: 18,
              color: charging ? AppColors.neonGreen : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '${l.alternator}: ${charging ? l.charging : l.notCharging}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
