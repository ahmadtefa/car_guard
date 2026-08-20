import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_title.dart';

/// Password-protected calibration screen — the Flutter twin of the
/// "Advanced Settings" modal in the original Kayan dashboard.
///
/// Covers: temperature offset, voltage calibration factor, the real-voltage
/// calibration wizard, divider/pull-up resistors, install date and a
/// restart command.
class AdvancedSettingsPage extends ConsumerStatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  ConsumerState<AdvancedSettingsPage> createState() =>
      _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends ConsumerState<AdvancedSettingsPage> {
  /// Calibration code shared with the original firmware dashboard.
  static const String _calibrationCode = '171978';

  final _password = TextEditingController();
  final _offset = TextEditingController();
  final _voltCalib = TextEditingController();
  final _realVolt = TextEditingController();
  final _r1 = TextEditingController();
  final _r2 = TextEditingController();
  final _pullUp = TextEditingController();
  final _installDate = TextEditingController();

  bool _unlocked = false;
  bool _loading = false;
  bool _busy = false;
  String? _passwordError;
  DeviceModuleSettings? _loaded;

  @override
  void dispose() {
    _password.dispose();
    _offset.dispose();
    _voltCalib.dispose();
    _realVolt.dispose();
    _r1.dispose();
    _r2.dispose();
    _pullUp.dispose();
    _installDate.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _unlock() async {
    if (_password.text.trim() == _calibrationCode) {
      setState(() {
        _unlocked = true;
        _passwordError = null;
      });

      await _load();
    } else {
      setState(() {
        _passwordError = 'Wrong calibration code!';
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final settings =
        await ref.read(esp8266RepositoryProvider).getDeviceSettings();

    if (!mounted) return;

    if (settings == null) {
      setState(() {
        _loading = false;
      });

      _snack('Could not read the module settings — is the device reachable?');
      return;
    }

    _offset.text = settings.offset.toStringAsFixed(1);
    _voltCalib.text = settings.voltCalib.toStringAsFixed(4);
    _r1.text = settings.r1.toStringAsFixed(0);
    _r2.text = settings.r2.toStringAsFixed(0);
    _pullUp.text = settings.sensorPullUp.toStringAsFixed(0);
    _installDate.text = settings.installDate;

    setState(() {
      _loaded = settings;
      _loading = false;
    });
  }

  double? _parseField(TextEditingController controller, String label) {
    final value = double.tryParse(controller.text.trim());

    if (value == null) {
      _snack('$label must be a number.');
      return null;
    }

    return value;
  }

  Future<void> _save() async {
    final offset = _parseField(_offset, 'Temperature offset');
    final voltCalib = _parseField(_voltCalib, 'Voltage calibration');
    final r1 = _parseField(_r1, 'R1');
    final r2 = _parseField(_r2, 'R2');
    final pullUp = _parseField(_pullUp, 'Pull-up');

    if (offset == null ||
        voltCalib == null ||
        r1 == null ||
        r2 == null ||
        pullUp == null) {
      return;
    }

    if (voltCalib <= 0) {
      _snack('Voltage calibration must be greater than zero.');
      return;
    }

    if (r1 <= 0 || r2 <= 0 || pullUp <= 0) {
      _snack('Resistances must be greater than zero.');
      return;
    }

    setState(() => _busy = true);

    final ok = await ref
        .read(esp8266RepositoryProvider)
        .saveAdvancedSettings(
          (_loaded ?? const DeviceModuleSettings()).copyWith(
            offset: offset,
            voltCalib: voltCalib,
            r1: r1,
            r2: r2,
            sensorPullUp: pullUp,
            installDate: _installDate.text.trim(),
          ),
        );

    if (!mounted) return;

    setState(() => _busy = false);

    _snack(ok ? 'Calibration saved' : 'Failed — device reachable?');
  }

  Future<void> _calibrateVoltage() async {
    final realVolt = _parseField(_realVolt, 'Real voltage');

    if (realVolt == null) return;

    if (realVolt < 8 || realVolt > 18) {
      _snack('Enter a voltage between 8 and 18 V.');
      return;
    }

    setState(() => _busy = true);

    final newFactor = await ref
        .read(esp8266RepositoryProvider)
        .calibrateVoltage(realVolt);

    if (!mounted) return;

    setState(() => _busy = false);

    if (newFactor == null) {
      _snack(
        'Calibration failed — check the connection and the voltage value.',
      );
      return;
    }

    _voltCalib.text = newFactor.toStringAsFixed(4);

    _snack('Calibrated! New factor: ${newFactor.toStringAsFixed(4)}');
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_installDate.text.trim());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) return;

    final two = (int value) => value.toString().padLeft(2, '0');

    setState(() {
      _installDate.text =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}';
    });
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

  Widget _buildLockScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: AppSpacing.lg),
            Text('Advanced settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Enter the calibration code to continue.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppTextField(
              controller: _password,
              labelText: 'Calibration code',
              hintText: '••••••',
              obscureText: true,
              onSubmitted: (_) => _unlock(),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              onPressed: _unlock,
              child: const Text('Unlock'),
            ),
            if (_passwordError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _passwordError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Calibration')),
        body: _buildLockScreen(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Calibration')),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.padding,
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SectionTitle(
                title: 'Reading calibration',
                subtitle: 'Fine-tune what the module reports.',
              ),
              AppTextField(
                controller: _offset,
                labelText: 'Temperature offset (±°C)',
                hintText: '0.0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
              ),
              AppTextField(
                controller: _voltCalib,
                labelText: 'Voltage calibration factor',
                hintText: '0.9724',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: AppSpacing.padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voltage wizard',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Measure the battery with a multimeter and enter the '
                        'real value — the module recalculates its factor.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _realVolt,
                        labelText: 'Real measured voltage (V)',
                        hintText: '12.60',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        onPressed: _busy ? null : _calibrateVoltage,
                        child: const Text('Calibrate voltage now'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              SectionTitle(
                title: 'Voltage divider & sensor',
                subtitle: 'Hardware values of your module.',
              ),
              AppTextField(
                controller: _r1,
                labelText: 'R1 resistance (ohm)',
                hintText: '2155',
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _r2,
                labelText: 'R2 resistance (ohm)',
                hintText: '390',
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _pullUp,
                labelText: 'Sensor pull-up resistance (ohm)',
                hintText: '4700',
                keyboardType: TextInputType.number,
              ),
              AppTextField(
                controller: _installDate,
                labelText: 'Install date (yyyy-mm-dd)',
                hintText: '2025-01-15',
                enabled: false,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: _pickDate,
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save calibration'),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                onPressed: _busy ? null : _restartDevice,
                child: const Text('Restart module'),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                onPressed: _loading ? null : _load,
                child: const Text('Reload from module'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
