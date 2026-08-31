// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Solar / Energy colors
  static const Color primaryColor = Color(0xFF1565C0); // Deep Blue
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color secondaryColor = Color(0xFFFFA000); // Amber - Solar
  static const Color successColor = Color(0xFF2E7D32); // Green
  static const Color warningColor = Color(0xFFE65100); // Orange
  static const Color errorColor = Color(0xFFC62828); // Red
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // Status colors
  static const Map<String, Color> statusColors = {
    'study': Color(0xFF1565C0),
    'inspection': Color(0xFF6A1B9A),
    'pricing': Color(0xFF00838F),
    'quotation': Color(0xFFE65100),
    'contracted': Color(0xFF2E7D32),
    'under_execution': Color(0xFF0277BD),
    'completed': Color(0xFF1B5E20),
    'suspended': Color(0xFF795548),
    'cancelled': Color(0xFFC62828),
  };

  static Color getStatusColor(String status) {
    return statusColors[status] ?? primaryColor;
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      fontFamily: GoogleFonts.cairo().fontFamily,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: cardColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: GoogleFonts.cairo(),
        hintStyle: GoogleFonts.cairo(),
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 28),
          headlineMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 24),
          headlineSmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          titleSmall: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          bodySmall: TextStyle(fontSize: 12),
        ),
      ),
      scaffoldBackgroundColor: backgroundColor,
    );
  }
}
