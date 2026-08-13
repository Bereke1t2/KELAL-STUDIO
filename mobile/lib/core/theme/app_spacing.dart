/// 4px base grid, pulled from Figma `Spacing & Radius Foundations`
/// (node `12:54`). Sized for comfortable thumb targets on low-end Android
/// devices — see [minTapTarget].
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 40;
  static const double xxxxxl = 48;

  /// The design system's explicit accessibility floor: "min 44-48px tap
  /// target per accessibility NFR" for low-end Android devices. Enforced by
  /// `/a11y-check` — see mobile/.claude/commands/a11y-check.md. Use 48
  /// (== [xxxxxl]) as the default target size for any tappable control.
  static const double minTapTarget = 48;
}

/// Radius scale from the same Figma node as [AppSpacing].
abstract final class AppRadius {
  static const double none = 0;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double full = 999;
}
