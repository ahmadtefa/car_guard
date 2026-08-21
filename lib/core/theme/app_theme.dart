import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';

/// Central theme configuration for light and dark modes.
abstract final class AppTheme {
  AppTheme._();

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.backgroundDark,
  );
}

/// Riverpod notifier للتحكم في وضع الإضاءة (نهاري/ليلي)
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// التبديل بين النهاري والليلي
  void toggle() {
    switch (state) {
      case ThemeMode.light:
        state = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        state = ThemeMode.light;
        break;
      case ThemeMode.system:
        // لو كان system، حوّل حسب سطوع الجهاز الحالي
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        state =
            brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
        break;
    }
  }

  void setMode(ThemeMode mode) => state = mode;

  /// هل الوضع الحالي ليلي؟
  bool isDark(BuildContext context) {
    switch (state) {
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }
}
