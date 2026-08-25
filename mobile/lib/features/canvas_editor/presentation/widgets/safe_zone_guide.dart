import 'package:flutter/material.dart';

import 'package:kelal_studio/core/render_engine/safe_zone_constants.dart';

/// Editor-time visual guide for `SafeZoneConstants`' top/bottom
/// obstruction bands — semi-transparent shading over the excluded regions
/// so a user can see, while dragging, roughly where a target platform's
/// own UI chrome is likely to sit once posted (PRD §6.5). Purely visual:
/// `IgnorePointer`-wrapped so it never intercepts the drag/tap gestures
/// `_DraggableTextLayer` (in `canvas_editor_page.dart`) needs on the layers
/// underneath/around it.
///
/// Sized to the same on-screen box the `CustomPaint`/`RenderEngine.paint`
/// canvas occupies (passed in as [boxSize]) — deliberately **not**
/// `CanvasScene.canvasSize` (the full-resolution export target), same
/// screen-px-vs-canvas-px distinction `CanvasEditorBloc.normalizedDragDelta`
/// documents.
class SafeZoneGuide extends StatelessWidget {
  const SafeZoneGuide({required this.boxSize, super.key});

  final Size boxSize;

  @override
  Widget build(BuildContext context) {
    final topHeight = boxSize.height * SafeZoneConstants.topObstructionFraction;
    final bottomHeight =
        boxSize.height * SafeZoneConstants.bottomObstructionFraction;
    // Neutral, semi-transparent dark shading — visible against light and
    // dark backgrounds alike (an app-theme-driven color here would be
    // wrong anyway: this shades the *generated graphic's* content, which
    // has its own, arbitrary background, not the app's own light/dark
    // theme).
    const shade = Color(0x40000000);

    return IgnorePointer(
      child: Column(
        children: [
          Container(
            key: const Key('safe_zone_guide_top'),
            height: topHeight,
            color: shade,
          ),
          const Spacer(),
          Container(
            key: const Key('safe_zone_guide_bottom'),
            height: bottomHeight,
            color: shade,
          ),
        ],
      ),
    );
  }
}
