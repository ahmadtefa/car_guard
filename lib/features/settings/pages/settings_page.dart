import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/background_monitor.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../providers/settings_provider.dart';
import '../widgets/device_pairing_section.dart';
import '../widgets/module_settings_section.dart';

/// The single place for every setting in the app: module alarm limits and
/// Wi-Fi, app alert thresholds, appearance, demo and background monitoring.
///
/// (The standalone `/device-settings` screen was merged into this page so
/// users no longer have to guess which "settings" entry edits what.)
///
/// Every change is persisted immediately; text fields are persisted through
/// the save button so half-typed addresses are never stored.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  AppSettings get _current =>
      ref.read(settingsProvider).value ?? const AppSettings();

  Future<void> _save(AppSettings settings) async {
    await ref.read(settingsProvider.notifier).save(settings);

    if (!mounted) return;

    final l = ref.read(l10nProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.settingsSaved)),
    );
  }

  Future<void> _resetToDefaults() async {
    await BackgroundMonitor.stop();

    await _save(const AppSettings());
  }

  Future<void> _toggleBackground(bool value) async {
    final l = ref.read(l10nProvider);

    if (value) {
      debugPrint('BG TOGGLE: initializing notifications…');

      final granted =
          await ref.read(notificationServiceProvider).initialize();

      debugPrint('BG TOGGLE: notifications granted=$granted');

      // Belt & suspenders: ask through permission_handler too — some
      // Android 13+ builds only register the grant this way.
      final permissionStatus = await Permission.notification.request();
      debugPrint('BG TOGGLE: permission_handler status=$permissionStatus');

      if (!granted && !permissionStatus.isGranted) {
        _showError(l.notificationsRequired);
        return;
      }

      await BackgroundMonitor.requestIgnoreBatteryOptimization();

      final started = await BackgroundMonitor.start();

      debugPrint('BG TOGGLE: service started=$started '
          '(error: ${BackgroundMonitor.lastError})');

      if (!started) {
        final detail = BackgroundMonitor.lastError;
        _showError(
          detail == null ? l.serviceStartFailed : '${l.serviceStartFailed}\n$detail',
        );
        return;
      }
    } else {
      await BackgroundMonitor.stop();
    }

    await _save(_current.copyWith(backgroundMonitoringEnabled: value));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? l.serviceStarted : l.serviceStopped)),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _testFan() async {
    final l = ref.read(l10nProvider);

    final ok = await ref.read(esp8266RepositoryProvider).testFan();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.fanTestStarted : l.commandFailed),
      ),
    );
  }

  Future<void> _restartDevice() async {
    final l = ref.read(l10nProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.restartModuleQ),
        content: Text(l.restartConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.restart),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref.read(esp8266RepositoryProvider).restartDevice();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l.restartMsg : l.restartFailed)),
    );
  }

  /// Demo mode requires the demo code before it can be enabled.
  static const String _demoCode = '1122';

  Future<void> _toggleDemo(bool value) async {
    final l = ref.read(l10nProvider);

    if (!value) {
      await _save(_current.copyWith(demoModeEnabled: false));
      return;
    }

    final granted = await _askDemoCode(l);

    if (granted) {
      await _save(_current.copyWith(demoModeEnabled: true));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.wrongDemoCode)),
      );
    }
  }

  Future<bool> _askDemoCode(AppL10n l) async {
    final controller = TextEditingController();
    var error = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l.demoCodeLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l.demoCodeLabel,
                  errorText: error ? l.wrongDemoCode : null,
                ),
                onSubmitted: (value) {
                  if (value.trim() == _demoCode) {
                    Navigator.of(dialogContext).pop(true);
                  } else {
                    setDialogState(() => error = true);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim() == _demoCode) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  setDialogState(() => error = true);
                }
              },
              child: Text(l.unlock),
            ),
          ],
        ),
      ),
    );

    controller.dispose();

    return result ?? false;
  }

  String _styleLabel(String name, AppL10n l) {
    return switch (name) {
      'racing' => l.styleRacing,
      'sporty' => l.styleSporty,
      'segments' => l.styleSegments,
      'sweeper' => l.styleSweeper,
      'ring' => l.styleRing,
      'led' => l.styleLed,
      'needle' => l.styleNeedle,
      'orb' => l.styleOrb,
      'combo' => l.styleCombo,
      _ => l.styleCards,
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    final l = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.padding,
          children: [
            const DevicePairingSection(),

            const ModuleSettingsSection(),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(
              title: l.advancedSection,
              subtitle: l.advancedSectionInfo,
            ),
            SecondaryButton(
              onPressed: () => context.push('/advanced-settings'),
              child: Text(l.advancedModuleSettings),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              onPressed: settings.demoModeEnabled ? null : _testFan,
              child: Text(l.testFan),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              onPressed: () => context.push('/ota-update'),
              child: Text(l.otaUpdate),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              onPressed: settings.demoModeEnabled ? null : _restartDevice,
              child: Text(l.restartDevice),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(title: l.dashboardStyle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final name in AppSettings.dashboardStyleNames)
                    ChoiceChip(
                      label: Text(_styleLabel(name, l)),
                      selected: settings.dashboardStyleName == name,
                      onSelected: (_) => _save(
                        settings.copyWith(dashboardStyleName: name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(title: l.demoMode, subtitle: l.demoModeInfo),
            SwitchListTile(
              title: Text(l.simulatedDevice),
              subtitle: Text(l.simulatedDeviceInfo),
              value: settings.demoModeEnabled,
              onChanged: _toggleDemo,
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(
              title: l.backgroundSection,
              subtitle: l.backgroundSectionInfo,
            ),
            SwitchListTile(
              title: Text(l.backgroundToggle),
              subtitle: Text(l.backgroundToggleInfo),
              value: settings.backgroundMonitoringEnabled,
              onChanged: _toggleBackground,
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(title: l.alertsSection, subtitle: l.alertsSectionInfo),
            SwitchListTile(
              title: Text(l.alertsEnabled),
              subtitle: Text(l.alertsEnabledInfo),
              value: settings.alertsEnabled,
              onChanged: (value) =>
                  _save(settings.copyWith(alertsEnabled: value)),
            ),
            if (settings.alertsEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  l.moduleLimitsNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SwitchListTile(
                title: Text(l.coolantAlerts),
                subtitle: Text(l.coolantAlertsInfo),
                value: settings.coolantAlertsEnabled,
                onChanged: (value) =>
                    _save(settings.copyWith(coolantAlertsEnabled: value)),
              ),
              SwitchListTile(
                title: Text(l.connectionAlerts),
                subtitle: Text(l.connectionAlertsInfo),
                value: settings.connectionAlertsEnabled,
                onChanged: (value) =>
                    _save(settings.copyWith(connectionAlertsEnabled: value)),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              onPressed: _resetToDefaults,
              child: Text(l.resetToDefaults),
            ),
          ],
        ),
      ),
    );
  }
}
