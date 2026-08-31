// lib/presentation/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.wb_sunny, size: 60, color: Colors.amber),
                  const SizedBox(height: 8),
                  Text(
                    'Solar Manager',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'نظام إدارة محطات الطاقة الشمسية',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الإصدار ${AppConstants.version}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings items
          _SettingsTile(
            icon: Icons.person,
            title: 'معلومات المستخدم',
            subtitle: 'اسم المستخدم والدور',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.business,
            title: 'معلومات الشركة',
            subtitle: 'اسم الشركة والشعار',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.attach_money,
            title: 'العملة',
            subtitle: 'الجنيه المصري (ج.م)',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.backup,
            title: 'النسخ الاحتياطي',
            subtitle: 'تصدير قاعدة البيانات',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('سيتم إضافة هذه الخاصية قريباً')),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'حول التطبيق',
            subtitle: 'معلومات الإصدار والترخيص',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Solar Manager',
                applicationVersion: AppConstants.version,
                applicationIcon:
                    const Icon(Icons.wb_sunny, color: Colors.amber, size: 40),
                children: const [
                  Text(
                    'نظام إدارة محطات الطاقة الشمسية\n'
                    'يعمل بدون إنترنت (Offline First)\n'
                    'جاهز للتوسع مستقبلاً',
                    textDirection: TextDirection.rtl,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),
          // Version info
          Center(
            child: Text(
              'Solar Manager v${AppConstants.version}\nOffline First - Cloud Ready',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle,
            style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
