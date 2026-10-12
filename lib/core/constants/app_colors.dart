import 'package:flutter/material.dart';

/// Shared automotive palette. Semantic colors must be used consistently:
/// cyan for active/live data, amber for caution, red for critical conditions.
abstract final class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF13B8D4);
  static const Color backgroundLight = Color(0xFFF3F6FA);
  static const Color backgroundDark = Color(0xFF080E16);
  static const Color textPrimary = Color(0xFF101A27);
  static const Color textSecondary = Color(0xFF526174);

  static const Color success = Color(0xFF18B779);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFF04452);

  static const Color neonCyan = Color(0xFF35D9F2);
  static const Color neonMagenta = Color(0xFFE879F9);
  static const Color neonGreen = Color(0xFF39D98A);
  static const Color neonRed = Color(0xFFFF5263);
  static const Color neonAmber = Color(0xFFFFB547);
}
