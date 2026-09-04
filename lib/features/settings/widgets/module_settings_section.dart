import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/device_models.dart';
import '../../../core/services/esp8266_repository.dart';
import '../../../core/services/network_binding_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../license/providers/license_provider.dart';
import '../providers/settings_provider.dart';

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
  final _speedLimit = TextEditingController();

  DeviceModuleSettings? _loaded;
  bool _loading = true;
  bool _saving = false;
  bool _speedInitialized = false;
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
    _speedLimit.dispose();
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
        minVolt < 8 || minVolt > 28 ||
        maxVolt < 12 || maxVolt > 30) {
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

  /// [STA+mDNS] Sends the external network (hotspot/router) credentials to
  /// the module — it joins it alongside its own AP and becomes discoverable
  /// as car_guard.local.
  Future<void> _factoryReset() async {
    final l = ref.read(l10nProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.factoryResetModule),
        content: Text(l.factoryResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.factoryResetModule),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    final ok = await ref
        .read(esp8266RepositoryProvider)
        .factoryResetModule();

    if (!mounted) return;

    setState(() => _saving = false);

    _snack(ok ? l.factoryResetDone : l.joinNetworkFailed);
  }

  Future<void> _saveWifi() async {
    final l = ref.read(l10nProvider);

    final ssid = _ssid.text.trim();
    final password = _password.text;

    if (ssid.isEmpty || ssid.length > 32) {
      _snack(l.ssidTooShort);
      return;
    }

    // باسوورد نقطة وصول الجهاز نفسه: مفتوحة (0) أو WPA2 (8-63)
    // القديم كان يرفض <8 ويمنع الشبكات المفتوحة أو الباسوورد القصير
    if (password.isNotEmpty && password.length < 8) {
      _snack(l.passwordTooShort);
      return;
    }
    if (password.length > 63) {
      _snack(l.passwordTooShort);
      return;
    }

    setState(() => _saving = true);

    final ok = await ref
        .read(esp8266RepositoryProvider)
        .saveWifiSettings(ssid: ssid, password: password);

    if (!mounted) return;

    setState(() => _saving = false);

    if (ok) {
      await _syncStoredWifiCredentials(ssid, password);
    }

    // The module restarts its access point right after saving, so a missing
    // "OK" reply is not necessarily a failure — mirror the original UX.
    _snack(ok ? l.wifiSent(ssid) : l.wifiSent(ssid));
  }

  /// The module restarted its AP with the new name/password — keep the
  /// phone-side stored credentials (direct pairing + system auto-join) in
  /// sync so both keep working after the rename instead of pointing at a
  /// dead network.
  Future<void> _syncStoredWifiCredentials(
    String ssid,
    String password,
  ) async {
    try {
      final storage = ref.read(storageServiceProvider);

      final oldSsid =
          await storage.read(Esp8266Repository.pairingSsidKey) ?? '';
      final oldPass =
          await storage.read(Esp8266Repository.pairingPassKey) ?? '';

      await storage.write(Esp8266Repository.pairingSsidKey, ssid);
      await storage.write(Esp8266Repository.pairingPassKey, password);

      final autoJoin =
          (await storage.read(Esp8266Repository.autoJoinEnabledKey)) == 'true';
      if (!autoJoin) return;

      if (oldSsid.isNotEmpty && (oldSsid != ssid || oldPass != password)) {
        await NetworkBindingService.removeModuleWifiSuggestion(
          ssid: oldSsid,
          password: oldPass,
        );
      }

      await NetworkBindingService.suggestModuleWifi(
        ssid: ssid,
        password: password,
      );
    } catch (_) {
      // Sync is best-effort: the module save itself already succeeded.
    }
  }

  Future<void> _saveSpeedLimit() async {
    final l = ref.read(l10nProvider);

    final value = _parseField(_speedLimit, l.speedLimit);
    if (value == null) return;

    if (value < 20 || value > 240) {
      _snack(l.valueOutOfRange(l.speedLimit));
      return;
    }

    final settings =
        ref.read(settingsProvider).value ?? const AppSettings();

    await ref
        .read(settingsProvider.notifier)
        .save(settings.copyWith(speedLimit: value));

    _snack(l.settingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final settingsState = ref.watch(settingsProvider);
    final demoEnabled = settingsState.value?.demoModeEnabled ?? false;
    final moduleLicensed =
        settingsState.value != null &&
        !demoEnabled &&
        ref.watch(licenseAuthorizationProvider);

    // Prefill the app-side speed limit once settings are loaded.
    if (!_speedInitialized) {
      final appSettings = ref.watch(settingsProvider).value;
      if (appSettings != null) {
        _speedLimit.text = appSettings.speedLimit.toStringAsFixed(0);
        _speedInitialized = true;
      }
    }

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

          // Alarm-limit fields get their own warning-tinted card so they
          // never blend in with the rest of the settings.
          Card(
            color: AppColors.warning.withValues(alpha: 0.12),
            elevation: 0,
            child: Padding(
              padding: AppSpacing.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l.alarmLimits,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                    onPressed: !_saving && moduleLicensed ? _saveLimits : null,
                    child: Text(l.saveToModule),
                  ),

                  const Divider(height: AppSpacing.xl),

                  // Phone-side-only limit: the module has no GPS, so the
                  // speeding threshold lives in the app settings.
                  Text(
                    l.speedLimitInfo,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  AppTextField(
                    controller: _speedLimit,
                    labelText: l.speedLimit,
                    hintText: '120',
                    keyboardType: TextInputType.number,
                  ),
                  SecondaryButton(
                    onPressed: _saving ? null : _saveSpeedLimit,
                    child: Text(l.saveAppSide),
                  ),
                ],
              ),
            ),
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
            onPressed: !_saving && moduleLicensed ? _saveWifi : null,
            child: Text(l.saveWifi),
          ),
          const SizedBox(height: AppSpacing.xl),

          SectionTitle(
            title: l.factoryResetModule,
            subtitle: l.factoryResetInfo,
          ),
          SecondaryButton(
            onPressed: !_saving && moduleLicensed ? _factoryReset : null,
            child: Text(l.factoryResetModule),
          ),
        ],
      ],
    );
  }
}
