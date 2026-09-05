import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/widget_updater_provider.dart';
import '../core/services/background_monitor.dart';
import '../core/theme/app_theme.dart';
import '../features/analysis/providers/analysis_provider.dart';
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

    // Background monitoring consumes the same read-only telemetry as the
    // foreground dashboard. It must not be disabled merely because the
    // module is LOCKED; protected hardware controls remain separately gated
    // in the repository and firmware.
    void syncBackgroundMonitor() {
      final settings = ref.read(settingsProvider).value;
      final canMonitor =
          settings != null &&
          !settings.demoModeEnabled &&
          settings.backgroundMonitoringEnabled;

      if (canMonitor) {
        // Convert the bool result to Future<void> for unawaited(); the
        // listener only cares that the transition is fire-and-forget.
        unawaited(BackgroundMonitor.start().then<void>((_) {}));
      } else {
        unawaited(BackgroundMonitor.stop());
      }
    }

    ref.listen(settingsProvider, (_, _) => syncBackgroundMonitor());
    // `ref.listen` starts on the next provider change in Riverpod 3. Run the
    // initial synchronization explicitly so persisted settings are honored
    // on the first build as well.
    syncBackgroundMonitor();

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