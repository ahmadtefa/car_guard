import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_l10n.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../settings/providers/settings_provider.dart';

class DeviceConnectionPage extends ConsumerStatefulWidget {
  const DeviceConnectionPage({super.key});

  @override
  ConsumerState<DeviceConnectionPage> createState() =>
      _DeviceConnectionPageState();
}

class _DeviceConnectionPageState
    extends ConsumerState<DeviceConnectionPage> {
  late final TextEditingController _hostController;

  bool _connecting = false;

  @override
  void initState() {
    super.initState();

    // Prefill with the last address the user saved in settings.
    final settings =
        ref.read(settingsProvider).value ?? const AppSettings();

    _hostController = TextEditingController(text: settings.deviceHost);
  }

  AppSettings get _settings =>
      ref.read(settingsProvider).value ?? const AppSettings();

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    final l = ref.read(l10nProvider);

    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.enterAddressFirst)),
      );
      return;
    }

    setState(() {
      _connecting = true;
    });

    try {
      final repository = ref.read(esp8266RepositoryProvider);

      await repository.connect(
        host: host,
        port: _settings.devicePort,
      );

      // Remember the address so the next launch reconnects automatically.
      await ref.read(settingsProvider.notifier).save(
            _settings.copyWith(deviceHost: host),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.connecting)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.connectionError}\n$e')),
      );
    }

    if (mounted) {
      setState(() {
        _connecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    final repository = ref.read(esp8266RepositoryProvider);

    await repository.disconnect();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ref.read(l10nProvider).disconnectedMsg),
      ),
    );
  }

  Future<void> _reconnect() async {
    final repository = ref.read(esp8266RepositoryProvider);

    await repository.reconnect();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ref.read(l10nProvider).reconnecting),
      ),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(deviceStatusProvider);
    final l = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.deviceConnection),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: status.when(
          data: (device) {
            final connected = device.connected;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected ? '🟢 ${l.connected}' : '🔴 ${l.disconnected}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('${l.deviceLabel}: ${device.deviceId}'),
                        Text(
                          '${l.lastUpdateLabel}: '
                          '${device.lastUpdated.hour}:'
                          '${device.lastUpdated.minute}',
                        ),
                        Text('${l.portLabel}: ${_settings.devicePort}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _hostController,
                  enabled: !connected,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l.deviceIpLabel,
                    hintText: '192.168.4.1',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                if (!connected)
                  ElevatedButton(
                    onPressed: _connecting ? null : _connect,
                    child: _connecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(l.connectAction),
                  ),
                if (connected)
                  ElevatedButton(
                    onPressed: _disconnect,
                    child: Text(l.disconnectAction),
                  ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _reconnect,
                  child: Text(l.reconnectAction),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (_, error) => Center(
            child: Text('${l.connectionError}: $error'),
          ),
        ),
      ),
    );
  }
}
