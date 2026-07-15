import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/device_status_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(deviceStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Guard TEST'),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/connection');
        },
        icon: const Icon(Icons.wifi),
        label: const Text('TEST BUTTON'),
      ),

      body: deviceState.when(
        data: (status) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoCard(
                'Connection',
                status.connected ? 'Connected' : 'Disconnected',
              ),

              _infoCard(
                'Battery Voltage',
                '${status.batteryData.voltage} V',
              ),

              _infoCard(
                'Engine Temperature',
                '${status.temperatureData.engineTemperature} °C',
              ),

              _infoCard(
                'Coolant Level',
                status.coolantLevelData.coolantAvailable
                    ? 'OK'
                    : 'LOW',
              ),

              _infoCard(
                'Cooling Fan',
                status.controlData.fanRunning
                    ? 'Running'
                    : 'OFF',
              ),

              _infoCard(
                'Buzzer',
                status.controlData.buzzerActive
                    ? 'ON'
                    : 'OFF',
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text(
            error.toString(),
          ),
        ),
      ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}