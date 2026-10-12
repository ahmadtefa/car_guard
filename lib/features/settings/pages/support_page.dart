import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/device_status_provider.dart';
import '../../../core/providers/device_provider.dart';
import '../../../core/services/device_models.dart';
import '../../license/providers/license_provider.dart';
import '../providers/settings_provider.dart';

/// A lightweight, read-only diagnostic and help center.
///
/// It deliberately avoids changing firmware settings or starting actuators;
/// destructive/physical self-tests remain behind the existing Advanced
/// Settings controls.
class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final status = ref.watch(deviceStatusProvider).value;
    final licensed = ref.watch(licenseAuthorizationProvider);
    final isAr = settings?.languageName == 'ar';

    final connected = status?.connected == true;
    final age = connected && status != null
        ? DateTime.now().difference(status.lastUpdated)
        : null;
    final fresh = age != null && age.inSeconds <= 5;
    final temp = status?.temperatureData.engineTemperature;
    final voltage = status?.batteryData.voltage;
    final limits = status?.moduleLimits;

    String yesNo(bool value) => isAr ? (value ? 'نعم' : 'لا') : (value ? 'Yes' : 'No');
    String state(bool value) => value
        ? (isAr ? 'سليم' : 'OK')
        : (isAr ? 'يحتاج مراجعة' : 'Check');

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'التشخيص والمساعدة' : 'Diagnostics & Help'),
      ),
      body: ListView(
        padding: AppSpacing.padding,
        children: [
          _SectionCard(
            title: isAr ? 'فحص النظام' : 'System diagnostics',
            icon: Icons.health_and_safety_outlined,
            children: [
              _DiagnosticRow(
                icon: Icons.wifi_rounded,
                label: isAr ? 'اتصال الجهاز' : 'Device connection',
                value: connected
                    ? (isAr ? 'متصل' : 'Connected')
                    : (isAr ? 'غير متصل' : 'Disconnected'),
                ok: connected,
              ),
              _DiagnosticRow(
                icon: Icons.update_rounded,
                label: isAr ? 'حداثة البيانات' : 'Telemetry freshness',
                value: connected && age != null
                    ? '${age.inSeconds}s'
                    : (isAr ? 'لا توجد قراءة' : 'No reading'),
                ok: fresh,
              ),
              _DiagnosticRow(
                icon: Icons.verified_user_outlined,
                label: isAr ? 'الترخيص' : 'License authorization',
                value: settings?.demoModeEnabled == true
                    ? (isAr ? 'وضع تجريبي' : 'Demo mode')
                    : state(licensed),
                ok: settings?.demoModeEnabled == true || licensed,
              ),
              _DiagnosticRow(
                icon: Icons.thermostat_outlined,
                label: isAr ? 'قراءة الحرارة' : 'Temperature reading',
                value: temp != null ? '${temp.toStringAsFixed(1)} °C' : '--',
                ok: temp != null && temp.isFinite,
              ),
              _DiagnosticRow(
                icon: Icons.battery_std_outlined,
                label: isAr ? 'قراءة البطارية' : 'Battery voltage',
                value: voltage != null ? '${voltage.toStringAsFixed(2)} V' : '--',
                ok: voltage != null && voltage.isFinite,
              ),
              _DiagnosticRow(
                icon: Icons.tune_rounded,
                label: isAr ? 'حدود الوحدة' : 'Module limits',
                value: limits != null && limits.minVolt < limits.maxVolt
                    ? (isAr ? 'متاحة' : 'Available')
                    : (isAr ? 'غير متاحة' : 'Unavailable'),
                ok: limits != null && limits.minVolt < limits.maxVolt,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: isAr ? 'ماذا تعني النتائج؟' : 'What the checks mean',
            icon: Icons.info_outline_rounded,
            children: [
              _HelpTile(
                title: isAr ? 'غير متصل' : 'Disconnected',
                body: isAr
                    ? 'تأكد أن الهاتف متصل بشبكة Car Guard أو أن عنوان الجهاز المحفوظ صحيح. التطبيق لا يعرض قراءات قديمة كأنها حية.'
                    : 'Make sure the phone is connected to the Car Guard Wi-Fi or the saved host is correct. The app intentionally does not present stale readings as live.',
              ),
              _HelpTile(
                title: isAr ? 'بيانات قديمة' : 'Stale telemetry',
                body: isAr
                    ? 'إذا مر أكثر من بضع ثوانٍ بدون تحديث، أعد الاتصال بالشبكة وانتظر إعادة الاتصال التلقائي قبل الاعتماد على القراءة.'
                    : 'If telemetry stops updating for several seconds, restore the network and allow the automatic reconnect to settle before relying on the reading.',
              ),
              _HelpTile(
                title: isAr ? 'قراءة البطارية' : 'Battery voltage',
                body: isAr
                    ? 'هذه قراءة الجهد الفعلية من Car Guard. حدود التحذير تأتي من إعدادات الوحدة عندما تكون متاحة.'
                    : 'This is the actual battery voltage reported by Car Guard. Warning limits come from the module settings when available.',
              ),
              _HelpTile(
                title: isAr ? 'وضع Demo' : 'Demo mode',
                body: isAr
                    ? 'الوضع التجريبي يستخدم محاكيًا داخليًا ولا يمثل قياسات السيارة الحقيقية. استخدمه لاختبار الواجهة والتحليل فقط.'
                    : 'Demo mode uses the built-in simulator and does not represent real vehicle measurements. Use it for UI and analysis testing only.',
              ),
              _HelpTile(
                title: isAr ? 'الترخيص' : 'License',
                body: isAr
                    ? 'القراءات الحقيقية محمية بحالة ACTIVE الحالية. بيانات الترخيص نفسها لا تدخل في النسخة الاحتياطية للإعدادات.'
                    : 'Real-module readings are protected by the current ACTIVE authorization. License material is intentionally excluded from settings backups.',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: AppSpacing.padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.build_circle_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isAr
                          ? 'للاختبارات التي قد تشغّل المروحة أو تعيد تشغيل الوحدة، استخدم قسم الإعدادات المتقدمة بعد التأكد من أن السيارة في حالة آمنة.'
                          : 'For tests that may run the fan or restart the module, use Advanced Settings only after making sure the vehicle is in a safe state.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              '${isAr ? 'Car Guard — إصدار التطبيق' : 'Car Guard — App build'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(body),
        ),
      ],
    );
  }
}
