import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_provider.dart';
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

  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
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
      ],
    );
  }
}
