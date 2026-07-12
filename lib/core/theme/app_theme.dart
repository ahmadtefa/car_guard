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

/// Riverpod provider for switching the app theme mode.
final themeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);
