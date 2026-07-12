import 'package:flutter/material.dart';

/// Shared spacing values used across the design system.
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const EdgeInsets padding = EdgeInsets.all(lg);
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets verticalPadding = EdgeInsets.symmetric(vertical: lg);
}
