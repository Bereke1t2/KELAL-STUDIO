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
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
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

  /// Defaults to the single-line behavior every existing call site
  /// (login/register/brand-kit fields) relies on. Added for the Idea
  /// Composer's multi-line free-text input (`features/composer`) — pass a
  /// value greater than 1 (or `null` for "grow unbounded") to opt into a
  /// multi-line field; no dedicated Figma "textarea" variant exists to
  /// pull a different visual from, so this reuses the same themed
  /// `InputDecorationTheme` and just widens the field vertically.
  final int? maxLines;

  /// Forwarded to [TextField.minLines]. Left `null` (single visual row
  /// until the user types more) unless the caller wants a fixed minimum
  /// height multi-line field.
  final int? minLines;

  /// Forwarded to [TextField.maxLength]. `null` (the default) leaves the
  /// field unbounded — most existing fields (email, name, single-line
  /// values) have no reason to cap length. Added for the Idea Composer's
  /// free-text input, which needed a client-side ceiling in front of a
  /// paid, quota-consuming generation call — see `composer_page.dart`'s
  /// `_maxIdeaLength`.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
