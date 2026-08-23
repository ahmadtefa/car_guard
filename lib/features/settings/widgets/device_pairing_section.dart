import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/services/esp8266_repository.dart';
import '../../../core/services/network_binding_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/settings_provider.dart';

/// The only connection control left in Settings: the direct app-scoped
/// Wi-Fi pairing switch (module link + 4G internet at the same time).
///
/// The module address itself is intentionally NOT editable anymore — end
/// users should never see or touch it; the default `192.168.4.1` is fixed.
class DevicePairingSection extends ConsumerStatefulWidget {
  const DevicePairingSection({super.key});

  @override
  ConsumerState<DevicePairingSection> createState() =>
      _DevicePairingSectionState();
}

class _DevicePairingSectionState
    extends ConsumerState<DevicePairingSection> {
  final _ssidController = TextEditingController(text: 'CarGuard');
  final _passController = TextEditingController();

  bool _pairing = false;
  bool _autoJoin = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPairingPrefs();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _loadPairingPrefs() async {
    final storage = ref.read(storageServiceProvider);

    final enabled =
        (await storage.read(Esp8266Repository.pairingEnabledKey)) == 'true';
    final autoJoin =
        (await storage.read(Esp8266Repository.autoJoinEnabledKey)) == 'true';
    final ssid =
        await storage.read(Esp8266Repository.pairingSsidKey) ?? 'CarGuard';
    final pass = await storage.read(Esp8266Repository.pairingPassKey) ?? '';

    if (!mounted) return;

    setState(() {
      _pairing = enabled;
      _autoJoin = autoJoin;
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

    // Android 10-12 additionally refuses Wi-Fi pairing when Location
    // services are off (even with the permission granted).
    if (await NetworkBindingService.androidSdkLevel() < 33) {
      final gps = await Permission.location.serviceStatus;
      if (!gps.isEnabled) {
        _snack(l.pairingNeedsGps);
        return;
      }
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
  }

  /// System-level auto-join (WifiNetworkSuggestion): after a one-time
  /// Android approval the phone joins the module network on its own,
  /// exactly like any other saved Wi-Fi network.
  Future<void> _setAutoJoin(bool enabled) async {
    final l = ref.read(l10nProvider);
    final storage = ref.read(storageServiceProvider);

    final ssid = _ssidController.text.trim();
    final password = _passController.text;

    if (ssid.isEmpty) return;

    setState(() => _busy = true);

    if (enabled) {
      final ok = await NetworkBindingService.suggestModuleWifi(
        ssid: ssid,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _busy = false;
        if (ok) _autoJoin = true;
      });

      if (ok) {
        // The same fields identify the module network for both features —
        // keep the stored credentials in sync so the auto-reapply on the
        // next app start registers exactly what the user sees here.
        await storage.write(Esp8266Repository.pairingSsidKey, ssid);
        await storage.write(Esp8266Repository.pairingPassKey, password);
        await storage.write(Esp8266Repository.autoJoinEnabledKey, 'true');
        _snack(l.autoJoinApprovalNote);
      } else {
        _snack(l.autoJoinFailed);
      }
      return;
    }

    // Turning auto-join off is best-effort: a missing suggestion is a
    // harmless no-op, so the switch always settles to OFF.
    await NetworkBindingService.removeModuleWifiSuggestion(
      ssid: ssid,
      password: password,
    );
    await storage.write(Esp8266Repository.autoJoinEnabledKey, 'false');

    if (!mounted) return;

    setState(() {
      _busy = false;
      _autoJoin = false;
    });

    _snack(l.settingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    final l = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(l.directPairTitle),
          subtitle: Text(l.directPairInfo),
          value: _pairing,
          onChanged: (settings.demoModeEnabled || _busy)
              ? null
              : (value) => value ? _startPairing() : _stopPairing(),
        ),
        SwitchListTile(
          title: Text(l.autoJoinTitle),
          subtitle: Text(l.autoJoinInfo),
          value: _autoJoin,
          onChanged: (settings.demoModeEnabled || _busy)
              ? null
              : (value) => _setAutoJoin(value),
        ),
        if (_pairing || _autoJoin) ...[
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
