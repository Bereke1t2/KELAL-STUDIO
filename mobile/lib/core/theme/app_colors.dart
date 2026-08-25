import 'package:flutter/material.dart';

/// Semantic color tokens pulled 1:1 from the Kelal Studio Figma design
/// system (`Color Foundations`, node `9:31`, file `0dIrGk2LyVEseP6Tz1KxMa`).
///
/// Field names mirror the Figma variable names exactly (`bg/canvas` →
/// [bgCanvas], `border/focus` → [borderFocus], etc.) so there is a
/// traceable 1:1 mapping back to the design file — see
/// mobile/.claude/skills/flutter-design-system/SKILL.md. Never hardcode a
/// hex value in a widget; always go through `context.colors` (see
/// [AppColorsContext] below).
///
/// Values marked "derived" were not directly pulled from a Figma node
/// during initial scaffolding (only the Light-mode interactive/feedback
/// swatches were fetched) — they're built from the *same* primitive ramps
/// the light-mode values come from, following the same bg/border/text
/// ramp-position pattern Figma uses elsewhere. Verify against Figma's
/// actual dark-mode interactive/feedback frames before shipping a real
/// dark-mode screen; don't silently assume this guess is exact.
@immutable
class AppColors {
  const AppColors({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgSurfaceRaised,
    required this.bgInverse,
    required this.bgBrandSubtle,
    required this.bgAccentSubtle,
    required this.bgDisabled,
    required this.borderDefault,
    required this.borderSubtle,
    required this.borderStrong,
    required this.borderFocus,
    required this.borderError,
    required this.borderBrand,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primaryDefault,
    required this.primaryHover,
    required this.primaryPressed,
    required this.primaryDisabledBg,
    required this.interactiveDestructiveDefault,
    required this.successBg,
    required this.successBorder,
    required this.successText,
    required this.warningBg,
    required this.warningBorder,
    required this.warningText,
    required this.errorBg,
    required this.errorBorder,
    required this.errorText,
    required this.infoBg,
    required this.infoBorder,
    required this.infoText,
  });

  final Color bgCanvas;
  final Color bgSurface;
  final Color bgSurfaceRaised;
  final Color bgInverse;
  final Color bgBrandSubtle;
  final Color bgAccentSubtle;
  final Color bgDisabled;

  final Color borderDefault;
  final Color borderSubtle;
  final Color borderStrong;
  final Color borderFocus;
  final Color borderError;
  final Color borderBrand;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color primaryDefault;
  final Color primaryHover;
  final Color primaryPressed;
  final Color primaryDisabledBg;

  /// "Destructive (fill)" / Default state, node `9:442` (Color Foundations,
  /// `Color — Interactive States`). Pulled as a raw swatch, not a bound
  /// Figma variable — no `color/*` name to mirror, so this uses the same
  /// `interactive*` naming Figma's own Tailwind export used for buttons
  /// (e.g. `--color-interactive-primary-default`). Used by
  /// `AppBottomSheet`'s destructive action (e.g. "Delete Draft").
  final Color interactiveDestructiveDefault;

  final Color successBg;
  final Color successBorder;
  final Color successText;

  final Color warningBg;
  final Color warningBorder;
  final Color warningText;

  final Color errorBg;
  final Color errorBorder;
  final Color errorText;

  final Color infoBg;
  final Color infoBorder;
  final Color infoText;

  static const light = AppColors(
    bgCanvas: Color(0xFFFAFAFA),
    bgSurface: Color(0xFFFFFFFF),
    bgSurfaceRaised: Color(0xFFFFFFFF),
    bgInverse: Color(0xFF171717),
    bgBrandSubtle: Color(0xFFFDF6E7),
    bgAccentSubtle: Color(0xFFFBEAEC),
    bgDisabled: Color(0xFFF4F4F4),
    borderDefault: Color(0xFFE7E7E7),
    borderSubtle: Color(0xFFF4F4F4),
    borderStrong: Color(0xFFA3A3A3),
    borderFocus: Color(0xFFA8690F),
    borderError: Color(0xFFA32424),
    borderBrand: Color(0xFFC6821F),
    textPrimary: Color(0xFF171717),
    textSecondary: Color(0xFF565656),
    textTertiary: Color(0xFF757575),
    primaryDefault: Color(0xFF855312),
    primaryHover: Color(0xFF633E12),
    primaryPressed: Color(0xFF402A10),
    primaryDisabledBg: Color(0xFFE7E7E7),
    interactiveDestructiveDefault: Color(0xFF8A1D1D),
    successBg: Color(0xFFEAF7EE),
    successBorder: Color(0xFF5CB279),
    successText: Color(0xFF1C4C2C),
    warningBg: Color(0xFFFDF0E6),
    warningBorder: Color(0xFFE68B45),
    warningText: Color(0xFF632908),
    errorBg: Color(0xFFFBEAEA),
    errorBorder: Color(0xFFD67575),
    errorText: Color(0xFF6E1717),
    infoBg: Color(0xFFEAF2FA),
    infoBorder: Color(0xFF63A6DA),
    infoText: Color(0xFF1C4468),
  );

  static const dark = AppColors(
    bgCanvas: Color(0xFF0D0D0D),
    bgSurface: Color(0xFF171717),
    bgSurfaceRaised: Color(0xFF262626),
    bgInverse: Color(0xFFFAFAFA),
    bgBrandSubtle: Color(0xFF402A10),
    bgAccentSubtle: Color(0xFF270B10),
    bgDisabled: Color(0xFF262626),
    borderDefault: Color(0xFF3D3D3D),
    borderSubtle: Color(0xFF262626),
    borderStrong: Color(0xFF757575),
    borderFocus: Color(0xFFDA9B29),
    borderError: Color(0xFFC24A4A),
    borderBrand: Color(0xFFC6821F),
    // derived — see class doc
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFD1D1D1),
    textTertiary: Color(0xFFA3A3A3),
    // derived — see class doc
    primaryDefault: Color(0xFFC6821F),
    primaryHover: Color(0xFFDA9B29),
    primaryPressed: Color(0xFFEAB44E),
    primaryDisabledBg: Color(0xFF262626),
    // derived — not pulled 1:1 (see class doc); reuses errorBorder's dark
    // value since both sit in the same red family at a similar "accent on
    // dark surface" ramp position. Verify against a real Figma dark-mode
    // pull before shipping a destructive action seen in dark mode.
    interactiveDestructiveDefault: Color(0xFFC24A4A),
    // derived from the same green/orange/red/blue primitive ramps the light
    // triads come from — see class doc
    successBg: Color(0xFF143820),
    successBorder: Color(0xFF3B935A),
    successText: Color(0xFF93D2A6),
    warningBg: Color(0xFF421B05),
    warningBorder: Color(0xFFA3450A),
    warningText: Color(0xFFF5B37C),
    errorBg: Color(0xFF3D1119),
    errorBorder: Color(0xFFC24A4A),
    errorText: Color(0xFFF3CCD1),
    infoBg: Color(0xFF0C2032),
    infoBorder: Color(0xFF3D87C4),
    infoText: Color(0xFFC9E0F3),
  );
}

extension AppColorsContext on BuildContext {
  /// Access the current brightness-appropriate token set, e.g.
  /// `context.colors.textPrimary`.
  AppColors get colors => Theme.of(this).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
}
