import 'package:flutter/material.dart';

import 'golden_helpers.dart';

/// Golden coverage for the primary button design-system primitive — scoped
/// to a single component, not a full screen, per
/// mobile/.claude/skills/flutter-testing/SKILL.md ("goldens on primitives,
/// not whole screens — full-screen goldens are high-maintenance/flaky").
///
/// This is a single `goldenThemeTest` call: `golden_helpers.dart`'s helper
/// crosses every variant below with both light and dark automatically, so
/// this one test produces 6 scenarios (3 variants x 2 themes) without
/// hand-duplicating a light and a dark copy of each. This is also the
/// first entry toward the Ethiopic golden-image regression corpus the PRD
/// (§6.7) mandates: an Amharic-label variant catches line-height/glyph
/// regressions early, in both themes, for free.
void main() {
  goldenThemeTest(
    'Primary button renders on-brand in light and dark',
    fileName: 'primary_button',
    variants: {
      'enabled - english': (context) => ElevatedButton(
        onPressed: () {},
        child: const Text('Generate Caption'),
      ),
      'enabled - amharic': (context) =>
          ElevatedButton(onPressed: () {}, child: const Text('መግለጫ ይፍጠሩ')),
      'disabled': (context) => const ElevatedButton(
        onPressed: null,
        child: Text('Generate Caption'),
      ),
    },
  );
}
