import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
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
  late final TextEditingController _hostController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();

    final settings =
        ref.read(settingsProvider).value ?? const AppSettings();

    _hostController = TextEditingController(text: settings.deviceHost);
    _portController = TextEditingController(
      text: settings.devicePort.toString(),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  AppSettings get _current =>
      ref.read(settingsProvider).value ?? const AppSettings();

  Future<void> _save(AppSettings settings) async {
    await ref.read(settingsProvider.notifier).save(settings);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _saveDeviceAddress() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (host.isEmpty) {
      _showError('Enter the device address first.');
      return;
    }

    if (port == null || port < 1 || port > 65535) {
      _showError('Port must be a number between 1 and 65535.');
      return;
    }

    await _save(
      _current.copyWith(deviceHost: host, devicePort: port),
    );
  }

  Future<void> _resetToDefaults() async {
    const defaults = AppSettings();

    _hostController.text = defaults.deviceHost;
    _portController.text = defaults.devicePort.toString();

    await _save(defaults);
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _styleLabel(String name) {
    return switch (name) {
      'racing' => 'Racing',
      'sporty' => 'Sporty',
      'segments' => 'Segments',
      'sweeper' => 'Sweeper',
      _ => 'Cards',
    };
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.padding,
          children: [
            SectionTitle(
              title: 'Device',
              subtitle: 'Address of the Car Guard ESP8266 module.',
            ),
            AppTextField(
              controller: _hostController,
              labelText: 'Device address',
              hintText: '192.168.4.1',
              prefixIcon: const Icon(Icons.router_outlined),
            ),
            AppTextField(
              controller: _portController,
              labelText: 'WebSocket port',
              hintText: '81',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.numbers_outlined),
            ),
            PrimaryButton(
              onPressed: _saveDeviceAddress,
              child: const Text('Save device'),
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              onPressed: () => context.push('/advanced-settings'),
              child: const Text('Advanced module settings'),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(
              title: 'Alerts',
              subtitle: 'Thresholds that trigger dashboard warnings and '
                  'notifications.',
            ),
            SwitchListTile(
              title: const Text('Alerts enabled'),
              subtitle: const Text('Master switch for all notifications.'),
              value: settings.alertsEnabled,
              onChanged: (value) =>
                  _save(settings.copyWith(alertsEnabled: value)),
            ),
            if (settings.alertsEnabled) ...[
              _ThresholdSlider(
                label: 'Engine temperature warning',
                unit: '°C',
                value: settings.engineTempWarning,
                min: 70,
                max: 130,
                divisions: 60,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(engineTempWarning: value)),
              ),
              _ThresholdSlider(
                label: 'Engine temperature critical',
                unit: '°C',
                value: settings.engineTempCritical,
                min: 80,
                max: 140,
                divisions: 60,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(engineTempCritical: value)),
              ),
              _ThresholdSlider(
                label: 'Minimum battery voltage',
                unit: 'V',
                value: settings.minBatteryVoltage,
                min: 10,
                max: 14,
                divisions: 40,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(minBatteryVoltage: value)),
              ),
              _ThresholdSlider(
                label: 'Maximum battery voltage',
                unit: 'V',
                value: settings.maxBatteryVoltage,
                min: 13,
                max: 16.5,
                divisions: 14,
                onChangedEnd: (value) =>
                    _save(settings.copyWith(maxBatteryVoltage: value)),
              ),
              SwitchListTile(
                title: const Text('Coolant alerts'),
                subtitle: const Text('Notify when the coolant level is low.'),
                value: settings.coolantAlertsEnabled,
                onChanged: (value) =>
                    _save(settings.copyWith(coolantAlertsEnabled: value)),
              ),
              SwitchListTile(
                title: const Text('Connection alerts'),
                subtitle: const Text(
                  'Notify when the device connection drops.',
                ),
                value: settings.connectionAlertsEnabled,
                onChanged: (value) =>
                    _save(settings.copyWith(connectionAlertsEnabled: value)),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(
              title: 'Dashboard style',
              subtitle: 'Pick how the live readings are displayed.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final name in AppSettings.dashboardStyleNames)
                    ChoiceChip(
                      label: Text(_styleLabel(name)),
                      selected: settings.dashboardStyleName == name,
                      onSelected: (_) => _save(
                        settings.copyWith(dashboardStyleName: name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(
              title: 'Appearance',
              subtitle: 'Choose how the app looks.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'system',
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Auto'),
                  ),
                  ButtonSegment(
                    value: 'light',
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {settings.themeModeName},
                onSelectionChanged: (selection) => _save(
                  settings.copyWith(themeModeName: selection.first),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            SectionTitle(
              title: 'Demo mode',
              subtitle: 'Simulate a Car Guard device to explore the app '
                  'without hardware.',
            ),
            SwitchListTile(
              title: const Text('Simulated device'),
              subtitle: const Text(
                'Feeds realistic readings so cards, charts and alerts work '
                'without the module.',
              ),
              value: settings.demoModeEnabled,
              onChanged: (value) =>
                  _save(settings.copyWith(demoModeEnabled: value)),
            ),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              onPressed: _resetToDefaults,
              child: const Text('Reset to defaults'),
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
