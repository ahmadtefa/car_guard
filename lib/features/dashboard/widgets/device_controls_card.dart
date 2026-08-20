import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../settings/providers/settings_provider.dart';
import 'base_dashboard_card.dart';

/// Dashboard card exposing direct commands to the physical module.
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
      SnackBar(
        content: Text(
          ok ? successMessage : 'Command failed — is the device reachable?',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoEnabled =
        ref.watch(settingsProvider).value?.demoModeEnabled ?? false;

    return BaseDashboardCard(
      title: 'Device Controls',
      value: '',
      subtitle: demoEnabled
          ? 'Disabled while demo mode is running'
          : 'Send commands straight to the module',
      statusText: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  onPressed: demoEnabled
                      ? null
                      : () => _send(
                            context,
                            ref,
                            () =>
                                ref.read(esp8266RepositoryProvider).muteBuzzer(),
                            'Buzzer muted',
                          ),
                  child: const Text('Mute buzzer'),
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
                            'Fan test started',
                          ),
                  child: const Text('Test fan'),
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
                      'Device is restarting',
                    ),
            child: const Text('Restart device'),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            onPressed: () => context.push('/device-settings'),
            child: const Text('Module settings'),
          ),
        ],
      ),
    );
  }
}
