import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';

/// Reusable text input field with consistent styling.
class AppTextField extends StatelessWidget {
  /// Creates an application text field.
  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
    this.onSubmitted,
  });

  /// Optional controller for the underlying text field.
  final TextEditingController? controller;

  /// Optional label displayed above the input.
  final String? labelText;

  /// Optional hint displayed inside the input.
  final String? hintText;

  /// Optional prefix icon.
  final Widget? prefixIcon;

  /// Optional suffix icon.
  final Widget? suffixIcon;

  /// Whether the input should obscure its text.
  final bool obscureText;

  /// Optional keyboard type.
  final TextInputType? keyboardType;

  /// Whether the field is enabled.
  final bool enabled;

  /// Called when the user submits the field (keyboard done button).
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: enabled,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          label: labelText == null
              ? null
              : Text(labelText!, softWrap: true),
          hint: hintText == null ? null : Text(hintText!, softWrap: true),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: AppRadius.medium),
          contentPadding: const EdgeInsets.all(AppSpacing.md),
        ),
      ),
    );
  }
}
