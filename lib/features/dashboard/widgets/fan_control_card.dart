import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/widgets/adaptive_text.dart';
import '../../../core/widgets/spinning_icon.dart';
import '../providers/fan_mode_provider.dart';

/// Manual fan control: pin the radiator fan on, or hand it back to the module.
///
/// The card never keeps its own idea of the fan state — [fanModeProvider]
/// derives it from the module's live stream — so what is shown here is what the
/// ESP8266 is actually doing: `automatic + off`, `automatic + running` and
/// `forced on` are three visibly different states, and a command that the module
/// did not acknowledge is reported as failed instead of optimistic.
class FanControlCard extends ConsumerStatefulWidget {
  const FanControlCard({super.key, this.compact = false});

  /// Hides the explanatory line inside the fullscreen layout.
  final bool compact;

  @override
  ConsumerState<FanControlCard> createState() => _FanControlCardState();
}

class _FanControlCardState extends ConsumerState<FanControlCard> {
  Future<void> _confirmAndSend(bool enable) async {
    final l = ref.read(l10nProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(enable ? l.fanForceConfirmTitle : l.fanReleaseConfirmTitle),
        content: Text(
          enable ? l.fanForceConfirmBody : l.fanReleaseConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: enable
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.neonRed),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(enable ? l.fanForceConfirmAction : l.fanReleaseConfirmAction),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final result = await ref.read(fanModeProvider.notifier).setForced(enable);

    if (!mounted) {
      return;
    }

    final message = switch (result) {
      FanCommandResult.confirmed => enable
          ? l.fanForcedOnMsg
          : l.fanReleasedMsg,
      FanCommandResult.sentUnconfirmed => l.fanUnconfirmedMsg,
      FanCommandResult.notConnected => l.fanNotConnectedMsg,
      FanCommandResult.failed => l.fanCommandFailedMsg,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: switch (result) {
          FanCommandResult.confirmed => AppColors.neonGreen,
          FanCommandResult.sentUnconfirmed => AppColors.neonAmber,
          _ => AppColors.neonRed,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final fan = ref.watch(fanModeProvider);
    final device = ref.watch(deviceStatusProvider).value;

    final connected = device?.connected ?? false;
    final fanRunning = device?.controlData.fanRunning ?? false;

    final statusText = !connected
        ? l.noData
        : fan.forced
        ? l.fanRunningForced
        : (fanRunning ? l.fanRunningAuto : l.fanStoppedAuto);

    final statusColor = !connected
        ? AppColors.textSecondary
        : fan.forced
        ? AppColors.neonRed
        : fanRunning
        ? AppColors.neonGreen
        : AppColors.neonAmber;

    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(
          color: fan.forced
              ? AppColors.neonRed.withAlpha(190)
              : theme.colorScheme.outlineVariant,
          width: fan.forced ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SpinningIcon(
                  icon: Icons.air,
                  spinning: connected && (fanRunning || fan.forced),
                  size: 22,
                  color: statusColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AdaptiveText(
                    l.fanControl,
                    style: (theme.textTheme.titleSmall ??
                            const TextStyle(fontSize: 14))
                        .copyWith(fontWeight: FontWeight.w800),
                    maxLines: 2,
                  ),
                ),
                if (connected && fan.modeReported) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _ModeChip(forced: fan.forced, l: l),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // The three distinct states, spelled out instead of an icon only.
            AdaptiveText(
              statusText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
              maxLines: 2,
            ),

            if (!widget.compact) ...[
              const SizedBox(height: AppSpacing.xs),
              AdaptiveText(
                connected && !fan.modeReported
                    ? l.fanForceUnsupportedMsg
                    : l.fanControlInfo,
                style: (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12))
                    .copyWith(
                      color: connected && !fan.modeReported
                          ? AppColors.neonAmber
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                maxLines: 3,
              ),
            ],

            if (!connected) ...[
              const SizedBox(height: AppSpacing.xs),
              AdaptiveText(
                l.fanNotConnectedMsg,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neonRed,
                ),
                maxLines: 2,
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: connected && !fan.pending
                        ? () => _confirmAndSend(!fan.forced)
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: fan.forced
                          ? AppColors.neonRed
                          : AppColors.neonGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.medium,
                      ),
                    ),
                    icon: Icon(
                      fan.forced
                          ? Icons.stop_circle_outlined
                          : Icons.air_rounded,
                      size: 22,
                    ),
                    // The label wraps instead of being cut on narrow phones.
                    label: AdaptiveText(
                      fan.forced ? l.fanReleaseButton : l.fanForceButton,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (fan.pending) ...[
                  const SizedBox(width: AppSpacing.md),
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ],
              ],
            ),

            if (fan.pending) ...[
              const SizedBox(height: AppSpacing.xs),
              AdaptiveText(
                l.sendingCommand,
                style: (theme.textTheme.bodySmall ?? const TextStyle())
                    .copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small pill telling the user *who* is driving the fan right now.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.forced, required this.l});

  final bool forced;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final color = forced ? AppColors.neonRed : AppColors.neonCyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.14).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha((255 * 0.6).round())),
      ),
      child: AdaptiveText(
        forced ? l.fanModeForced : l.fanModeAuto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: color,
        ),
        maxLines: 1,
        minFontSize: 9,
      ),
    );
  }
}
