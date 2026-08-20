import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../settings/providers/settings_provider.dart';

/// Full-screen HUD showing one giant live reading; tap anywhere to close.
///
/// Mirrors the original Kayan dashboard: the value turns red as soon as it
/// crosses the configured alert thresholds.
class FullscreenHudPage extends ConsumerWidget {
  const FullscreenHudPage({super.key, required this.type});

  /// Either 'temp' or 'volt'.
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceStatusProvider).value;
    final settings =
        ref.watch(settingsProvider).value ?? const AppSettings();

    final connected = device?.connected ?? false;
    final isTemp = type == 'temp';

    final temperature = device?.temperatureData.engineTemperature ?? 0;
    final voltage = device?.batteryData.voltage ?? 0;

    final Color color;
    final String valueText;
    final String labelText;

    if (isTemp) {
      valueText = connected ? '${temperature.toStringAsFixed(1)} °C' : '-- °C';
      labelText = 'ENGINE TEMP';

      color = !connected
          ? Colors.white30
          : temperature >= settings.engineTempCritical
          ? AppColors.neonRed
          : temperature >= settings.engineTempWarning
          ? AppColors.neonAmber
          : AppColors.neonMagenta;
    } else {
      valueText = connected ? '${voltage.toStringAsFixed(2)} V' : '--.- V';
      labelText = 'BATTERY VOLT';

      color = !connected
          ? Colors.white30
          : voltage <= settings.minBatteryVoltage ||
                voltage > settings.maxBatteryVoltage
          ? AppColors.neonRed
          : AppColors.neonGreen;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF040406),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                valueText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 84,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: color.withAlpha(120), blurRadius: 60),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                labelText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: color,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Tap to close',
                style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(
                  (255 * 0.35).round(),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
