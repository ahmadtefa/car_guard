import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/widgets/spinning_icon.dart';
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
    final device = settingsReady
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth >= 460
                ? (constraints.maxWidth - AppSpacing.lg) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _StatusItem(
                    icon: SpinningIcon(
                      icon: Icons.air,
                      spinning: fanOn,
                      size: 18,
                      color: fanOn
                          ? AppColors.neonGreen
                          : AppColors.neonAmber,
                    ),
                    text: '${l.fanShort}: ${fanOn ? l.on : l.off}',
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _StatusItem(
                    icon: SpinningIcon(
                      icon: Icons.settings,
                      spinning: charging,
                      duration: const Duration(milliseconds: 1200),
                      size: 18,
                      color: charging
                          ? AppColors.neonGreen
                          : AppColors.textSecondary,
                    ),
                    text:
                        '${l.alternator}: ${charging ? l.charging : l.notCharging}',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        icon,
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
