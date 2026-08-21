import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';

/// Settings that live on the Car Guard module itself: the alarm limits
/// (`/getallsettings` + `/saveallsettings`) and the module Wi-Fi
/// provisioning (`/getwifisettings` + `/savewifi`), plus a read-only info
/// card (serial / install date).
///
/// Rendered as a section inside the single Settings page — the separate
/// `/device-settings` screen was removed so every setting lives in one
/// place.
class ModuleSettingsSection extends ConsumerStatefulWidget {
  const ModuleSettingsSection({super.key});

  @override
  ConsumerState<ModuleSettingsSection> createState() =>
      _ModuleSettingsSectionState();
}

class _ModuleSettingsSectionState
    extends ConsumerState<ModuleSettingsSection> {
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
        _error = ref.read(l10nProvider).cantReadModule;
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

    // Prefill the Wi-Fi card with the credentials stored on the module.
    final wifi = await ref
        .read(esp8266RepositoryProvider)
        .getWifiSettings();

    if (!mounted || wifi == null) return;

    setState(() {
      _ssid.text = wifi.ssid;
      _password.text = wifi.password;
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
      _snack(ref.read(l10nProvider).mustBeNumber(label));
      return null;
    }

    return value;
  }

  Future<void> _saveLimits() async {
    final l = ref.read(l10nProvider);

    final alarmTemp = _parseField(_alarmTemp, l.alarmTempLabel);
    final fanOnTemp = _parseField(_fanOnTemp, l.fanOnTempLabel);
    final minVolt = _parseField(_minVolt, l.minVoltLabel);
    final maxVolt = _parseField(_maxVolt, l.maxVoltLabel);

    if (alarmTemp == null ||
        fanOnTemp == null ||
        minVolt == null ||
        maxVolt == null) {
      return;
    }

    // Ranges enforced by the firmware itself (handleSaveAllSettings).
    if (alarmTemp < 50 || alarmTemp > 150 ||
        fanOnTemp < 40 || fanOnTemp > 140 ||
        minVolt < 8 || minVolt > 14 ||
        maxVolt < 12 || maxVolt > 18) {
      _snack(l.valueOutOfRange(l.alarmLimits));
      return;
    }

    if (fanOnTemp >= alarmTemp) {
      _snack(l.fanLowerThanAlarm);
      return;
    }

    if (minVolt >= maxVolt) {
      _snack(l.minLowerThanMax);
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

    _snack(ok ? l.savedToModule : l.failedReachable);
  }

  Future<void> _saveWifi() async {
    final l = ref.read(l10nProvider);

    final ssid = _ssid.text.trim();
    final password = _password.text;

    if (ssid.length < 4) {
      _snack(l.ssidTooShort);
      return;
    }

    if (password.length < 8) {
      _snack(l.passwordTooShort);
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
    _snack(l.wifiSent(ssid));
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: l.moduleSettings,
          subtitle: l.reportedByFirmware,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(onPressed: _load, child: Text(l.retry)),
        ] else ...[
          Card(
            child: Padding(
              padding: AppSpacing.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l.serialLabel}: '
                    '${(_loaded?.serial.isEmpty ?? true) ? '--' : _loaded!.serial}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${l.installedLabel}: '
                    '${(_loaded?.installDate.isEmpty ?? true) ? l.unknownDate : _loaded!.installDate}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          AppTextField(
            controller: _fanOnTemp,
            labelText: l.fanOnTempLabel,
            hintText: '85',
            keyboardType: TextInputType.number,
          ),
          AppTextField(
            controller: _alarmTemp,
            labelText: l.alarmTempLabel,
            hintText: '95',
            keyboardType: TextInputType.number,
          ),
          AppTextField(
            controller: _minVolt,
            labelText: l.minVoltLabel,
            hintText: '12.0',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
          ),
          AppTextField(
            controller: _maxVolt,
            labelText: l.maxVoltLabel,
            hintText: '15.0',
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
          ),
          PrimaryButton(
            onPressed: _saving ? null : _saveLimits,
            child: Text(l.saveToModule),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionTitle(
            title: l.moduleWifi,
            subtitle: l.moduleWifiInfo,
          ),
          AppTextField(
            controller: _ssid,
            labelText: l.ssidLabel,
            hintText: 'CarGuard',
          ),
          AppTextField(
            controller: _password,
            labelText: l.passwordLabel,
            hintText: '12345678',
            obscureText: true,
          ),
          PrimaryButton(
            onPressed: _saving ? null : _saveWifi,
            child: Text(l.saveWifi),
          ),
        ],
      ],
    );
  }
}
