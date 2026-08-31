import 'package:flutter/material.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/widgets/safe_zone_guide.dart';

import 'golden_helpers.dart';

/// Golden coverage for the canvas editor's safe-zone shading guide —
/// scoped to the component itself, per
/// mobile/.claude/skills/flutter-testing/SKILL.md, rather than the whole
/// `CanvasEditorPage` (which needs a `CanvasEditorBloc`/`getIt`/
/// `AppLocalizations` context this widget itself has no dependency on —
/// see its own doc comment: purely visual, no locale-dependent text).
/// Painted over a bright background so the semi-transparent shading bands
/// (top/bottom obstruction fractions, `SafeZoneConstants`) are visible in
/// the golden image regardless of theme.
void main() {
  goldenThemeTest(
    'Safe zone guide shades the top/bottom obstruction bands over the '
    'canvas',
    fileName: 'safe_zone_guide',
    surfaceSize: const Size(360, 360),
    variants: {
      'default': (context) => const ColoredBox(
        color: Color(0xFFFFA500),
        child: SafeZoneGuide(boxSize: Size(328, 328)),
      ),
    },
  );
}
