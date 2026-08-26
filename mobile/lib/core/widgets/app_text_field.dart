import 'package:flutter/material.dart';

/// Themed text input — Figma `Components / Text Field`. The dedicated
/// component canvas for this one is named "Text Input" (node `17:2`, a
/// section-title text node) but its actual field mockup could not be
/// located in the file despite an extensive node-id sweep — see the
/// "Text Field" entry in `flutter-design-system/SKILL.md` for the exact
/// discrepancy. The floating-notched-label visual (label cut into the top
/// border, value text below) *was* pulled 1:1 from real usage in context
/// — Screens / Onboarding & Auth, "Sign Up — Default" → Field, node
/// `52:7` — which is Material's default `OutlineInputBorder` +
/// `labelText` behavior, already themed to match in
/// `core/theme/app_theme.dart`'s `inputDecorationTheme` (also pulled from
/// Figma). This widget is therefore a thin wrapper exposing the common
/// field API, not a from-scratch reimplementation.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.textInputAction,
    super.key,
  });

  /// Floating label text (becomes the notch cut into the border on focus
  /// or when non-empty).
  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;

  /// When non-null, renders the field in its error state (red border,
  /// helper text below) — Figma "Sign Up — Error" field, node `103:3`
  /// ("Error Row": icon + helper text under the field).
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
