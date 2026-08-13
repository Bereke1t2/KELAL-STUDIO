import 'dart:async';

import 'package:alchemist/alchemist.dart';

/// Alchemist's own `CiGoldensConfig` defaults to `obscureText: true` —
/// real text is replaced with solid boxes in the `goldens/ci/*.png`
/// baseline, specifically to avoid cross-machine font-rendering
/// differences causing flaky diffs. That default is wrong for this
/// project: the entire point of the golden corpus mandated by PRD §6.7
/// (mobile/.claude/skills/flutter-ethiopic-typography/SKILL.md) is to
/// catch real Ethiopic rendering regressions — a box has no glyph shape
/// to regress. Overriding `obscureText: false` here so the CI golden
/// (the one actually asserted against in `mobile-ci.yml`, which always
/// runs on the same `ubuntu-latest` image) shows real text.
///
/// This is safe here specifically because: the app bundles its own font
/// (`assets/fonts/NotoSansEthiopic-Regular.ttf`) rather than depending on
/// whatever fonts happen to be installed on a given machine, and the
/// Flutter SDK is pinned to an exact version via FVM — the two biggest
/// sources of the cross-machine variance `obscureText` exists to guard
/// against. Always run `fvm flutter test`, never the system Flutter, or
/// this guarantee doesn't hold.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      ciGoldensConfig: CiGoldensConfig(obscureText: false),
    ),
    run: testMain,
  );
}
