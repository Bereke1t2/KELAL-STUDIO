import 'package:kelal_studio/core/widgets/primary_button.dart';

import 'golden_helpers.dart';

/// Golden coverage for the primary button design-system primitive — scoped
/// to a single component, not a full screen, per
/// mobile/.claude/skills/flutter-testing/SKILL.md ("goldens on primitives,
/// not whole screens — full-screen goldens are high-maintenance/flaky").
///
/// Exercises the real [PrimaryButton] widget (`lib/core/widgets/primary_button.dart`)
/// rather than a raw `ElevatedButton` stand-in, now that the widget exists —
/// same themed `ElevatedButtonThemeData` underneath, so the pre-existing
/// enabled/disabled baselines are unaffected; `loading` is a new scenario
/// covering the `isLoading` spinner swap. `loadingValue` pins the spinner
/// to a fixed frame — see the doc comment on `PrimaryButton.loadingValue`
/// for why (an indeterminate spinner hangs `alchemist`'s default
/// `pumpAndSettle`).
///
/// This is a single `goldenThemeTest` call: `golden_helpers.dart`'s helper
/// crosses every variant below with both light and dark automatically, so
/// this one test produces 8 scenarios (4 variants x 2 themes) without
/// hand-duplicating a light and a dark copy of each. This is also part of
/// the Ethiopic golden-image regression corpus the PRD (§6.7) mandates: an
/// Amharic-label variant catches line-height/glyph regressions early, in
/// both themes, for free.
void main() {
  goldenThemeTest(
    'Primary button renders on-brand in light and dark',
    fileName: 'primary_button',
    variants: {
      'enabled - english': (context) =>
          PrimaryButton(label: 'Generate Caption', onPressed: () {}),
      'enabled - amharic': (context) =>
          PrimaryButton(label: 'መግለጫ ይፍጠሩ', onPressed: () {}),
      'disabled': (context) =>
          const PrimaryButton(label: 'Generate Caption', onPressed: null),
      'loading': (context) => PrimaryButton(
        label: 'Generate Caption',
        isLoading: true,
        loadingValue: 0.65,
        onPressed: () {},
      ),
    },
  );
}
