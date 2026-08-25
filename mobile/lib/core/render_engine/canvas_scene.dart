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

/// An optional brand-kit logo composited onto a [CanvasScene] — mirrors
/// [TextLayer]'s normalized-coordinate convention exactly, so both layer
/// types are positioned/sized the same resolution-independent way
/// regardless of whether the scene is painted at live-editor proxy size or
/// full export resolution.
@immutable
class LogoLayer {
  const LogoLayer({
    required this.image,
    required this.normalizedOffset,
    required this.normalizedWidth,
  });

  /// Decoded once, cached, and reused across every repaint — same
  /// decode-once discipline as [CanvasScene.backgroundImage]
  /// (mobile/.claude/skills/flutter-performance).
  final ui.Image image;

  /// Top-left corner, normalized 0..1 of the scene's `canvasSize`.
  final Offset normalizedOffset;

  /// Logo width as a fraction of the scene's `canvasSize.width`. Height is
  /// derived from [image]'s own aspect ratio at paint time
  /// (`RenderEngine._paintLogo`) rather than stored here separately — a
  /// second, independently-settable normalized height could distort the
  /// logo's aspect ratio, which a brand's actual logo mark should never be.
  final double normalizedWidth;

  LogoLayer copyWith({Offset? normalizedOffset, double? normalizedWidth}) {
    return LogoLayer(
      image: image,
      normalizedOffset: normalizedOffset ?? this.normalizedOffset,
      normalizedWidth: normalizedWidth ?? this.normalizedWidth,
    );
  }
}

/// The full authoritative state of one canvas composition: a background
/// image, an optional brand-kit logo overlay, plus 0-2 text layers. This is
/// the single model both the live editor (`features/canvas_editor`) and
/// the final export (`features/export`) paint from — see
/// `render_engine.dart`.
@immutable
class CanvasScene {
  const CanvasScene({
    required this.backgroundImage,
    required this.canvasSize,
    this.textLayers = const [],
    this.logo,
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

  /// Genuinely optional — most scenes have no logo (e.g. no brand kit
  /// configured, or the user hasn't attached one to this generation yet).
  /// `null` means "paint no logo," not "paint a default/placeholder one."
  final LogoLayer? logo;

  /// Note: passing `logo: null` here is indistinguishable from "don't
  /// change the logo" — this mirrors [textLayers]' existing `??` pattern
  /// and is fine for this branch's scope (nothing yet needs to *remove* an
  /// already-set logo mid-edit); a future branch that needs an explicit
  /// "clear the logo" affordance will need a sentinel-value copyWith
  /// instead of this simple one.
  CanvasScene copyWith({
    List<TextLayer>? textLayers,
    LogoLayer? logo,
    Size? canvasSize,
  }) {
    return CanvasScene(
      backgroundImage: backgroundImage,
      canvasSize: canvasSize ?? this.canvasSize,
      textLayers: textLayers ?? this.textLayers,
      logo: logo ?? this.logo,
    );
  }
}
