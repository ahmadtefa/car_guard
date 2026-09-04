import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/widget_updater_provider.dart';
import '../core/services/background_monitor.dart';
import '../core/theme/app_theme.dart';
import '../features/analysis/providers/analysis_provider.dart';
import '../features/license/providers/license_provider.dart';
import '../features/settings/providers/settings_provider.dart';
import 'router.dart';

/// Root application widget for Car Guard.
/// It wires together the router, the Material 3 theme, Riverpod and the
/// ar/en localization (including RTL layout for Arabic).
class CarGuardApp extends ConsumerWidget {
  const CarGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // يفعّل تحديث ويدجت الشاشة الرئيسية تلقائياً مع كل قراءة
    ref.watch(widgetUpdaterProvider);
    // يشغّل محرك التحليل المحلي من أول التشغيل (سجل التنبيهات + الإشعارات
    // المحلية للحالات الخطرة) من غير ما يعيد بناء الواجهة مع كل تحديث.
    ref.listen(analysisProvider, (_, _) {});

    // The background isolate must not keep processing real HTTP telemetry
    // after the current ESP8266 authorization is lost. It is restarted only
    // after a fresh ACTIVE report; the handler still relies on the module's
    // own HTTP response for final authority.
    void syncBackgroundMonitor() {
      final settings = ref.read(settingsProvider).value;
      final licenseAuthorized = ref.read(licenseAuthorizationProvider);
      final canMonitor =
          settings != null &&
          !settings.demoModeEnabled &&
          settings.backgroundMonitoringEnabled &&
          licenseAuthorized;

      if (canMonitor) {
        // Convert the bool result to Future<void> for unawaited(); the
        // listener only cares that the transition is fire-and-forget.
        unawaited(BackgroundMonitor.start().then<void>((_) {}));
      } else {
        unawaited(BackgroundMonitor.stop());
      }
    }

    ref.listen(licenseAuthorizationProvider, (_, _) => syncBackgroundMonitor(),
        fireImmediately: true);
    ref.listen(settingsProvider, (_, _) => syncBackgroundMonitor(),
        fireImmediately: true);

    final router = ref.watch(appRouterProvider);

    final settings = ref.watch(settingsProvider).value;

    final languageName = settings?.languageName ?? 'en';
    final isAr = languageName == 'ar';

    final themeModeName = settings?.themeModeName ?? 'system';

    final themeMode = switch (themeModeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Car Guard',
      debugShowCheckedModeBanner: false,
      locale: Locale(languageName),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}