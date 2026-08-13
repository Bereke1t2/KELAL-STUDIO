import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// One editable text layer on the canvas (PRD §6.9: "1-2 editable text
/// layers"). Positions are normalized (0..1 of canvas size) so the same
/// [CanvasScene] renders identically regardless of whether it's being
/// painted at proxy resolution (live editing) or full export resolution —
/// see mobile/.claude/skills/flutter-ethiopic-typography/SKILL.md for the
/// line-height/safe-zone rules [TextLayer.style] must respect.
@immutable
class TextLayer {
  const TextLayer({
    required this.id,
    required this.text,
    required this.normalizedOffset,
    required this.normalizedMaxWidth,
    required this.style,
    this.textAlign = TextAlign.left,
  });

  final String id;
  final String text;
  final Offset normalizedOffset;
  final double normalizedMaxWidth;
  final TextStyle style;
  final TextAlign textAlign;

  TextLayer copyWith({
    String? text,
    Offset? normalizedOffset,
    double? normalizedMaxWidth,
  }) {
    return TextLayer(
      id: id,
      text: text ?? this.text,
      normalizedOffset: normalizedOffset ?? this.normalizedOffset,
      normalizedMaxWidth: normalizedMaxWidth ?? this.normalizedMaxWidth,
      style: style,
      textAlign: textAlign,
    );
  }
}

/// The full authoritative state of one canvas composition: a background
/// image plus 0-2 text layers. This is the single model both the live
/// editor (`features/canvas_editor`) and the final export
/// (`features/export`) paint from — see `render_engine.dart`.
@immutable
class CanvasScene {
  const CanvasScene({
    required this.backgroundImage,
    required this.canvasSize,
    this.textLayers = const [],
  });

  /// Decoded once, cached, and reused across every repaint — never
  /// re-decode per frame (mobile/.claude/skills/flutter-performance).
  final ui.Image backgroundImage;

  /// The full-resolution output size this scene targets, e.g. 1080x1080.
  /// The live editor paints the same scene scaled down into a smaller
  /// [CustomPaint] box; it does not hold a second, separately-decoded
  /// downscaled bitmap of the background — only the interactive proxy
  /// gesture math is downscaled, per PRD §6.9.
  final Size canvasSize;

  final List<TextLayer> textLayers;

  CanvasScene copyWith({List<TextLayer>? textLayers}) {
    return CanvasScene(
      backgroundImage: backgroundImage,
      canvasSize: canvasSize,
      textLayers: textLayers ?? this.textLayers,
    );
  }
}
