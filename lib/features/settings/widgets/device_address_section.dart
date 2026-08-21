import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/esp8266_repository.dart';
import '../../../core/services/network_binding_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_title.dart';
import '../providers/settings_provider.dart';

/// Lets the user view and change the Car Guard module address, then
/// reconnects to it.
///
/// Default: `192.168.4.1` (the module's own access point). Needed when the
/// module joins another network — e.g. the phone's hotspot, which keeps the
/// phone's own internet on 4G at all times.
class DeviceAddressSection extends ConsumerStatefulWidget {
  const DeviceAddressSection({super.key});

  @override
  ConsumerState<DeviceAddressSection> createState() =>
      _DeviceAddressSectionState();
}

class _DeviceAddressSectionState
    extends ConsumerState<DeviceAddressSection> {
  final _hostController = TextEditingController();
  final _ssidController = TextEditingController(text: 'CarGuard');
  final _passController = TextEditingController();

  bool _initialized = false;
  bool _busy = false;
  bool _pairing = false;

  @override
  void initState() {
    super.initState();
    _loadPairingPrefs();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _loadPairingPrefs() async {
    final storage = ref.read(storageServiceProvider);

    final enabled =
        (await storage.read(Esp8266Repository.pairingEnabledKey)) == 'true';
    final ssid =
        await storage.read(Esp8266Repository.pairingSsidKey) ?? 'CarGuard';
    final pass = await storage.read(Esp8266Repository.pairingPassKey) ?? '';

    if (!mounted) return;

    setState(() {
      _pairing = enabled;
      _ssidController.text = ssid;
      _passController.text = pass;
    });
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _apply(AppSettings settings) async {
    final l = ref.read(l10nProvider);
    final host = _hostController.text.trim();

    if (host.isEmpty) return;

    setState(() => _busy = true);

    await ref
        .read(settingsProvider.notifier)
        .save(settings.copyWith(deviceHost: host));

    // Reconnect right away so the change takes effect without an app restart.
    await ref
        .read(esp8266RepositoryProvider)
        .connect(host: host, port: settings.devicePort);

    if (!mounted) return;

    setState(() => _busy = false);
    _snack(l.settingsSaved);
  }

  // ------------------------------------------------------------------
  // Direct app-scoped Wi-Fi pairing (keeps 4G as the internet route)
  // ------------------------------------------------------------------

  Future<bool> _ensurePairingPermission() async {
    final sdk = await NetworkBindingService.androidSdkLevel();

    if (sdk == 0) return false; // not Android
    if (sdk < 29) return false; // WifiNetworkSpecifier needs 10+

    // Android 13+ asks for NEARBY_WIFI_DEVICES; 10-12 needs fine location.
    final permission = sdk >= 33
        ? Permission.nearbyWifiDevices
        : Permission.locationWhenInUse;

    final status = await permission.request();

    return status.isGranted;
  }

  Future<void> _startPairing() async {
    final l = ref.read(l10nProvider);

    final granted = await _ensurePairingPermission();
    if (!granted) {
      _snack(l.pairingDenied);
      return;
    }

    final ssid = _ssidController.text.trim();
    final password = _passController.text;

    if (ssid.isEmpty) return;

    setState(() => _busy = true);

    final storage = ref.read(storageServiceProvider);
    await storage.write(
      Esp8266Repository.pairingEnabledKey,
      'true',
    );
    await storage.write(
      Esp8266Repository.pairingSsidKey,
      ssid,
    );
    await storage.write(
      Esp8266Repository.pairingPassKey,
      password,
    );

    final ok = await NetworkBindingService.pairWithModuleWifi(
      ssid: ssid,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      _pairing = ok;
    });

    _snack(ok ? l.pairingStarted : l.pairingUnsupported);
  }

  Future<void> _stopPairing() async {
    setState(() => _busy = true);

    await NetworkBindingService.unpairModuleWifi();
    await ref
        .read(storageServiceProvider)
        .write(Esp8266Repository.pairingEnabledKey, 'false');

    if (!mounted) return;

    setState(() {
      _busy = false;
      _pairing = false;
    });

    await _apply(
      ref.read(settingsProvider).value ?? const AppSettings(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    final l = ref.watch(l10nProvider);

    // Fill the field once with the persisted address.
    if (!_initialized) {
      _hostController.text = settings.deviceHost;
      _initialized = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: l.deviceConnection,
          subtitle: l.deviceAddressInfo,
        ),
        AppTextField(
          controller: _hostController,
          labelText: l.deviceAddressLabel,
          hintText: '192.168.4.1',
          keyboardType: TextInputType.url,
          enabled: !settings.demoModeEnabled && !_busy,
        ),
        PrimaryButton(
          onPressed: (settings.demoModeEnabled || _busy)
              ? null
              : () => _apply(settings),
          child: Text(l.applyAndReconnect),
        ),
        const SizedBox(height: AppSpacing.xl),

        SwitchListTile(
          title: Text(l.directPairTitle),
          subtitle: Text(l.directPairInfo),
          value: _pairing,
          onChanged: (settings.demoModeEnabled || _busy)
              ? null
              : (value) => value ? _startPairing() : _stopPairing(),
        ),
        if (_pairing) ...[
          AppTextField(
            controller: _ssidController,
            labelText: l.ssidLabel,
            hintText: 'CarGuard',
          ),
          AppTextField(
            controller: _passController,
            labelText: l.passwordLabel,
            obscureText: true,
          ),
        ],
      ],
    );
  }
}
