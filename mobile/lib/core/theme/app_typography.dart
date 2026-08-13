import 'package:flutter/widgets.dart';

/// Type scale pulled 1:1 from Figma `Typography Foundations` (node `12:2`).
///
/// Production font is **Noto Sans Ethiopic** (bundled — see
/// `assets/fonts/NotoSansEthiopic-Regular.ttf` and `pubspec.yaml`). Figma's
/// own proof uses Abyssinica SIL only because Noto Sans Ethiopic isn't in
/// Figma's font catalog; never use Abyssinica SIL in the app itself.
///
/// Line-height is fixed at **1.55×** across every size (Figma: "Line-height
/// fixed at 1.55× across every size per the brief's Ethiopic vertical-metrics
/// rule") — do not vary this per style. Hierarchy comes from size, spacing
/// and color, **never weight**: every style below is [FontWeight.w400]
/// deliberately, matching the single-weight family Figma proofs with.
///
/// See mobile/.claude/skills/flutter-ethiopic-typography/SKILL.md before
/// touching this file — line-height and font-fallback rules here are load
/// bearing for the PRD's #1-rated risk (Ethiopic text line collision).
abstract final class AppTypography {
  static const String fontFamily = 'NotoSansEthiopic';
  static const double lineHeightMultiplier = 1.55;

  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: lineHeightMultiplier,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: lineHeightMultiplier,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: lineHeightMultiplier,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: lineHeightMultiplier,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: lineHeightMultiplier,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: lineHeightMultiplier,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: lineHeightMultiplier,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
  );
}
