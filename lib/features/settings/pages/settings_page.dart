import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/background_monitor.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../providers/settings_provider.dart';

/// Lets the user configure the device address and alert thresholds.
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

      if (!granted) {
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

  String _styleLabel(String name, AppL10n l) {
    return switch (name) {
      'racing' => l.styleRacing,
      'sporty' => l.styleSporty,
      'segments' => l.styleSegments,
      'sweeper' => l.styleSweeper,
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
            SectionTitle(
              title: l.advancedSection,
              subtitle: l.advancedSectionInfo,
            ),
            SecondaryButton(
              onPressed: () => context.push('/advanced-settings'),
              child: Text(l.advancedModuleSettings),
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

            SectionTitle(title: l.appearance, subtitle: l.chooseLook),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'system',
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(l.auto),
                  ),
                  ButtonSegment(
                    value: 'light',
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(l.light),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(l.dark),
                  ),
                ],
                selected: {settings.themeModeName},
                onSelectionChanged: (selection) => _save(
                  settings.copyWith(themeModeName: selection.first),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'en', label: const Text('English')),
                  ButtonSegment(value: 'ar', label: const Text('العربية')),
                ],
                selected: {settings.languageName},
                onSelectionChanged: (selection) => _save(
                  settings.copyWith(languageName: selection.first),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(title: l.demoMode, subtitle: l.demoModeInfo),
            SwitchListTile(
              title: Text(l.simulatedDevice),
              subtitle: Text(l.simulatedDeviceInfo),
              value: settings.demoModeEnabled,
              onChanged: (value) =>
                  _save(settings.copyWith(demoModeEnabled: value)),
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
              _ThresholdSlider(
                label: l.engineTempWarningLabel,
                unit: '°C',
                value: settings.engineTempWarning,
                min: 70,
                max: 130,
                divisions: 60,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(engineTempWarning: value)),
              ),
              _ThresholdSlider(
                label: l.engineTempCriticalLabel,
                unit: '°C',
                value: settings.engineTempCritical,
                min: 80,
                max: 140,
                divisions: 60,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(engineTempCritical: value)),
              ),
              _ThresholdSlider(
                label: l.minBatteryVoltageLabel,
                unit: 'V',
                value: settings.minBatteryVoltage,
                min: 10,
                max: 14,
                divisions: 40,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(minBatteryVoltage: value)),
              ),
              _ThresholdSlider(
                label: l.maxBatteryVoltageLabel,
                unit: 'V',
                value: settings.maxBatteryVoltage,
                min: 13,
                max: 16.5,
                divisions: 14,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(maxBatteryVoltage: value)),
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

/// Slider row used to pick a numeric alert threshold.
///
/// Tracks the drag locally so the thumb follows the finger, then reports the
/// chosen value through [onChangedEnd] once the drag finishes.
class _ThresholdSlider extends StatefulWidget {
  const _ThresholdSlider({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChangedEnd,
  });

  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChangedEnd;

  @override
  State<_ThresholdSlider> createState() => _ThresholdSliderState();
}

class _ThresholdSliderState extends State<_ThresholdSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final value =
        (_dragValue ?? widget.value).clamp(widget.min, widget.max).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(widget.label)),
              Text(
                '${value.toStringAsFixed(1)} ${widget.unit}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          label: value.toStringAsFixed(1),
          onChanged: (newValue) => setState(() => _dragValue = newValue),
          onChangeEnd: (newValue) {
            setState(() => _dragValue = null);
            widget.onChangedEnd(newValue);
          },
        ),
      ],
    );
  }
}
