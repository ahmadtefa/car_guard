import 'package:flutter/material.dart';

/// Shared color palette for the application.
abstract final class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);

  /// Semantic colors used for status and alert UI.
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);

  /// Neon gauge palette matching the original Kayan dashboard design.
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color neonMagenta = Color(0xFFFF00FF);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonRed = Color(0xFFFF2244);
  static const Color neonAmber = Color(0xFFFFAA00);
}
