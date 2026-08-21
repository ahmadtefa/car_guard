import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/providers/driving_mode_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/driving_mode_button.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/battery_voltage_card.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/coolant_level_card.dart';
import '../widgets/engine_temperature_card.dart';
import '../widgets/fan_status_card.dart';
import '../widgets/voltage_difference_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final isDark = ref.watch(themeModeProvider.notifier).isDark(context);
    final isDrivingMode = ref.watch(drivingModeProvider);
    final deviceStatus = ref.watch(deviceStatusProvider);

    // حالة كتم الصوت - من بيانات الجهاز
    final isMuted = deviceStatus.maybeWhen(
      data: (status) => status.controlData.buzzerActive == false,
      orElse: () => false,
    );
    // لو الـ buzzerActive = true يعني في صوت شغال ولسه مش مكتوم
    final isBuzzerActive = deviceStatus.maybeWhen(
      data: (status) => status.controlData.buzzerActive,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Guard'),
        centerTitle: false,
        actions: [
          // 1) زرار وضع القيادة - يحافظ على الشاشة شغالة
          const DrivingModeButton(),
          const SizedBox(width: 1),

          // 2) زرار الوضع الليلي/النهاري
          IconButton(
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                key: ValueKey(isDark),
              ),
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
          const SizedBox(width: 1),

          // 3) زرار كتم الصوت
          IconButton(
            tooltip: isBuzzerActive ? 'كتم الصوت' : 'الصوت',
            icon: Icon(
              isBuzzerActive ? Icons.volume_off : Icons.volume_up,
              color: isBuzzerActive ? Theme.of(context).colorScheme.error : null,
            ),
            onPressed: () async {
              try {
                final repo = ref.read(esp8266RepositoryProvider);
                // إرسال أمر كتم للجهاز
                await repo.sendJson({"mute": 1, "command": "mute"});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isBuzzerActive ? 'تم كتم الصوت 🔇' : 'تم إلغاء الكتم 🔊'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في كتم الصوت: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 1),

          // 4) زرار الإعدادات
          IconButton(
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.push('/connection');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/connection');
        },
        icon: const Icon(Icons.wifi),
        label: const Text('Connection'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppSpacing.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بانر وضع القيادة يظهر فقط عند التفعيل
                const DrivingModeBanner(),

                ConnectionStatusCard(
                  statusText: state.connectionStatus,
                ),

                const SizedBox(height: AppSpacing.md),

                EngineTemperatureCard(
                  value: state.engineTemperature,
                ),

                const SizedBox(height: AppSpacing.md),

                BatteryVoltageCard(
                  value: state.batteryVoltage,
                  statusText: state.connectionStatus,
                ),

                const SizedBox(height: AppSpacing.md),

                VoltageDifferenceCard(
                  value: state.voltageDifference,
                  statusText: state.connectionStatus,
                ),

                const SizedBox(height: AppSpacing.md),

                CoolantLevelCard(
                  value: state.coolantLevel,
                  statusText: state.connectionStatus,
                ),

                const SizedBox(height: AppSpacing.md),

                FanStatusCard(
                  value: state.fanStatus,
                  statusText: state.connectionStatus,
                ),

                // كارت إضافي لتوضيح حالة وضع القيادة في الأسفل (اختياري)
                if (isDrivingMode) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'نصيحة: ثبّت الموبايل على حامل السيارة أثناء وضع القيادة',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
