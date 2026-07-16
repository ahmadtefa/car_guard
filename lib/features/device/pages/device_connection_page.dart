import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_provider.dart';
import '../../../core/providers/device_status_provider.dart';

class DeviceConnectionPage extends ConsumerStatefulWidget {
  const DeviceConnectionPage({super.key});

  @override
  ConsumerState<DeviceConnectionPage> createState() =>
      _DeviceConnectionPageState();
}

class _DeviceConnectionPageState
    extends ConsumerState<DeviceConnectionPage> {
  final TextEditingController _hostController =
      TextEditingController(text: '192.168.4.1');

  bool _connecting = false;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
    });

    try {
      final repository =
          ref.read(esp8266RepositoryProvider);

      await repository.connect(
        host: _hostController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting...'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection Error\n$e'),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _connecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    final repository =
        ref.read(esp8266RepositoryProvider);

    await repository.disconnect();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disconnected'),
      ),
    );
  }

  Future<void> _reconnect() async {
    final repository =
        ref.read(esp8266RepositoryProvider);

    await repository.reconnect();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reconnecting...'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Connection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: status.when(
          data: (device) {
            final connected = device.connected;

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected
                              ? '🟢 Connected'
                              : '🔴 Disconnected',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Device: ${device.deviceId}',
                        ),

                        Text(
                          'Last Update: '
                          '${device.lastUpdated.hour}:'
                          '${device.lastUpdated.minute}',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: _hostController,
                  enabled: !connected,
                  keyboardType:
                      TextInputType.url,
                  decoration:
                      const InputDecoration(
                    labelText: 'Device IP Address',
                    hintText: '192.168.4.1',
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                if (!connected)
                  ElevatedButton(
                    onPressed:
                        _connecting
                            ? null
                            : _connect,
                    child: _connecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Connect'),
                  ),

                if (connected)
                  ElevatedButton(
                    onPressed: _disconnect,
                    child:
                        const Text('Disconnect'),
                  ),

                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed: _reconnect,
                  child:
                      const Text('Reconnect'),
                ),
              ],
            );
          },

          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),

          error: (_, error) => Center(
            child: Text(
              'Error: $error',
            ),
          ),
        ),
      ),
    );
  }
}