import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/widgets/adaptive_text.dart';
import '../../../core/widgets/spinning_icon.dart';
import '../providers/fan_mode_provider.dart';

/// Single compact row replacing the old fan and alternator cards: an icon and
/// a short status for each.
///
/// The fan side spells out *who* is driving the fan (automatic control vs the
/// user's forced mode) so the row can never disagree with the fan control card
/// or with the module: all three read the same live stream. Text is sized to the
/// width it gets instead of being ellipsized, which is what used to cut
/// "المروحة لا تعمل" in half on small phones.
class FanAlternatorRow extends ConsumerWidget {
  const FanAlternatorRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final device = ref.watch(deviceStatusProvider).value;
    final fan = ref.watch(fanModeProvider);

    final connected = device?.connected ?? false;
    final fanOn = device?.controlData.fanRunning ?? false;
    final voltage = device?.batteryData.voltage ?? 0;

    final charging = connected && voltage >= 13.0;

    final fanText = !connected
        ? '${l.fanShort}: ${l.noData}'
        : fan.forced
        ? l.fanRunningForced
        : (fanOn ? l.fanRunningAuto : l.fanStoppedAuto);

    final fanColor = !connected
        ? AppColors.textSecondary
        : fan.forced
        ? AppColors.neonRed
        : fanOn
        ? AppColors.neonGreen
        : AppColors.neonAmber;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  SpinningIcon(
                    icon: Icons.air,
                    spinning: connected && (fanOn || fan.forced),
                    size: 18,
                    color: fanColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AdaptiveText(
                      fanText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Row(
                children: [
                  SpinningIcon(
                    icon: Icons.settings,
                    spinning: charging,
                    duration: const Duration(milliseconds: 1200),
                    size: 18,
                    color: charging
                        ? AppColors.neonGreen
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AdaptiveText(
                      '${l.alternator}: ${charging ? l.charging : l.notCharging}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
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
