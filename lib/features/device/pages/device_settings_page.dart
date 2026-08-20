import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_title.dart';

/// Reads and edits the settings stored on the ESP8266 module itself
/// (`/getallsettings`, `/saveallsettings`) and provisions its Wi-Fi
/// (`/savewifi`) — the Flutter twin of the original Kayan settings modal.
class DeviceSettingsPage extends ConsumerStatefulWidget {
  const DeviceSettingsPage({super.key});

  @override
  ConsumerState<DeviceSettingsPage> createState() =>
      _DeviceSettingsPageState();
}

class _DeviceSettingsPageState extends ConsumerState<DeviceSettingsPage> {
  final _fanOnTemp = TextEditingController();
  final _alarmTemp = TextEditingController();
  final _minVolt = TextEditingController();
  final _maxVolt = TextEditingController();
  final _ssid = TextEditingController();
  final _password = TextEditingController();

  DeviceModuleSettings? _loaded;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fanOnTemp.dispose();
    _alarmTemp.dispose();
    _minVolt.dispose();
    _maxVolt.dispose();
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final settings =
        await ref.read(esp8266RepositoryProvider).getDeviceSettings();

    if (!mounted) return;

    if (settings == null) {
      setState(() {
        _loading = false;
        _error = 'Could not read the module settings. Make sure the app is '
            'connected to the Car Guard device.';
      });
      return;
    }

    _fanOnTemp.text = settings.fanOnTemp.toStringAsFixed(0);
    _alarmTemp.text = settings.maxTemp.toStringAsFixed(0);
    _minVolt.text = settings.minVolt.toStringAsFixed(1);
    _maxVolt.text = settings.maxVolt.toStringAsFixed(1);

    setState(() {
      _loaded = settings;
      _loading = false;
    });
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double? _parseField(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim());

    if (value == null) {
      _snack('$label must be a number.');
      return null;
    }

    return value;
  }

  Future<void> _saveLimits() async {
    final alarmTemp = _parseField(_alarmTemp, 'Alarm temperature');
    final fanOnTemp = _parseField(_fanOnTemp, 'Fan temperature');
    final minVolt = _parseField(_minVolt, 'Minimum voltage');
    final maxVolt = _parseField(_maxVolt, 'Maximum voltage');

    if (alarmTemp == null ||
        fanOnTemp == null ||
        minVolt == null ||
        maxVolt == null) {
      return;
    }

    if (fanOnTemp >= alarmTemp) {
      _snack('Fan temperature must be lower than the alarm temperature.');
      return;
    }

    if (minVolt >= maxVolt) {
      _snack('Minimum voltage must be lower than the maximum voltage.');
      return;
    }

    setState(() => _saving = true);

    final ok = await ref
        .read(esp8266RepositoryProvider)
        .saveDeviceSettings(
          (_loaded ?? const DeviceModuleSettings()).copyWith(
            maxTemp: alarmTemp,
            fanOnTemp: fanOnTemp,
            minVolt: minVolt,
            maxVolt: maxVolt,
          ),
        );

    if (!mounted) return;

    setState(() => _saving = false);

    _snack(ok ? 'Settings saved to the module' : 'Failed — device reachable?');
  }

  Future<void> _testFan() async {
    final ok = await ref.read(esp8266RepositoryProvider).testFan();

    _snack(ok ? 'Fan test started (5 seconds)' : 'Fan test failed');
  }

  Future<void> _restartDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restart module?'),
        content: const Text(
          'The module will reboot and the connection will drop for a few '
          'seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await ref.read(esp8266RepositoryProvider).restartDevice();

    _snack(ok ? 'Module is restarting...' : 'Restart command failed');
  }

  Future<void> _saveWifi() async {
    final ssid = _ssid.text.trim();
    final password = _password.text;

    if (ssid.length < 4) {
      _snack('Network name must be at least 4 characters.');
      return;
    }

    if (password.length < 8) {
      _snack('Password must be at least 8 characters.');
      return;
    }

    setState(() => _saving = true);

    await ref
        .read(esp8266RepositoryProvider)
        .saveWifiSettings(ssid: ssid, password: password);

    if (!mounted) return;

    setState(() => _saving = false);

    // The module restarts its access point right after saving, so a missing
    // "OK" reply is not necessarily a failure — mirror the original UX.
    _snack('Wi-Fi settings sent — connect to "$ssid" if the module restarted.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Module Settings')),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.padding,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(onPressed: _load, child: const Text('Retry')),
            ] else ...[
              SectionTitle(
                title: 'Module info',
                subtitle: 'Reported by the firmware.',
              ),
              Card(
                child: Padding(
                  padding: AppSpacing.padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Serial: ${(_loaded?.serial.isEmpty ?? true) ? '--' : _loaded!.serial}'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Installed: ${(_loaded?.installDate.isEmpty ?? true) ? 'unknown' : _loaded!.installDate}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              SectionTitle(
                title: 'Alarm limits',
                subtitle: 'Saved directly on the module.',
              ),
              AppTextField(
                controller: _fanOnTemp,
                labelText: 'Fan ON temperature (°C)',
                hintText: '85',
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _alarmTemp,
                labelText: 'Alarm temperature (°C)',
                hintText: '95',
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _minVolt,
                labelText: 'Minimum battery voltage (V)',
                hintText: '12.0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              AppTextField(
                controller: _maxVolt,
                labelText: 'Maximum battery voltage (V)',
                hintText: '15.0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              PrimaryButton(
                onPressed: _saving ? null : _saveLimits,
                child: const Text('Save to module'),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(onPressed: _testFan, child: const Text('Test fan (5s)')),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                onPressed: _restartDevice,
                child: const Text('Restart module'),
              ),
              const SizedBox(height: AppSpacing.xl),

              SectionTitle(
                title: 'Module Wi-Fi',
                subtitle: 'The module will restart its network after saving.',
              ),
              AppTextField(
                controller: _ssid,
                labelText: 'Network name (SSID)',
                hintText: 'CarGuard',
              ),
              AppTextField(
                controller: _password,
                labelText: 'Password',
                hintText: '12345678',
                obscureText: true,
              ),
              PrimaryButton(
                onPressed: _saving ? null : _saveWifi,
                child: const Text('Save Wi-Fi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
