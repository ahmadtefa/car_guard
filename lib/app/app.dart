import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_l10n.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/providers/settings_provider.dart';
import 'router.dart';

/// Root application widget for Car Guard.
/// It wires together the router, the Material 3 theme, Riverpod and the
/// ar/en localization (including RTL layout for Arabic).
class CarGuardApp extends ConsumerWidget {
  const CarGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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