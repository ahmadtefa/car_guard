import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/alarm_provider.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../settings/providers/settings_provider.dart';
import 'base_dashboard_card.dart';

/// Dashboard card exposing direct commands to the physical module plus the
/// in-app alarm mute toggle.
class DeviceControlsCard extends ConsumerWidget {
  const DeviceControlsCard({super.key});

  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function() command,
    String successMessage,
  ) async {
    final ok = await command();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? successMessage : ref.read(l10nProvider).commandFailed)),
    );
  }

  Future<void> _toggleAlarm(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    bool demoEnabled,
  ) async {
    final next = !settings.alarmSoundEnabled;

    await ref
        .read(settingsProvider.notifier)
        .save(settings.copyWith(alarmSoundEnabled: next));

    if (!next) {
      await ref.read(alarmServiceProvider).stop();

      // Best-effort: also silence the module buzzer on real hardware.
      if (!demoEnabled) {
        await ref.read(esp8266RepositoryProvider).muteBuzzer();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(l10nProvider);

    final settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    final demoEnabled = settings.demoModeEnabled;

    return BaseDashboardCard(
      title: l.deviceControls,
      value: '',
      subtitle: demoEnabled ? l.disabledInDemo : l.sendCommandsInfo,
      statusText: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  onPressed: () =>
                      _toggleAlarm(context, ref, settings, demoEnabled),
                  child: Text(
                    settings.alarmSoundEnabled ? l.muteAlarm : l.enableAlarm,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SecondaryButton(
                  onPressed: demoEnabled
                      ? null
                      : () => _send(
                            context,
                            ref,
                            () => ref.read(esp8266RepositoryProvider).testFan(),
                            l.fanTestStarted,
                          ),
                  child: Text(l.testFan),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            onPressed: demoEnabled
                ? null
                : () => _send(
                      context,
                      ref,
                      () =>
                          ref.read(esp8266RepositoryProvider).restartDevice(),
                      l.deviceRestarting,
                    ),
            child: Text(l.restartDevice),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            onPressed: () => context.push('/device-settings'),
            child: Text(l.moduleSettings),
          ),
        ],
      ),
    );
  }
}
