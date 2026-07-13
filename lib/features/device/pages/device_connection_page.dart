import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/device_provider.dart';

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to ESP8266'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection failed: $e',
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Connection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _hostController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'ESP8266 IP Address',
                hintText: '192.168.4.1',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _connecting ? null : _connect,
                child: _connecting
                    ? const CircularProgressIndicator()
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}