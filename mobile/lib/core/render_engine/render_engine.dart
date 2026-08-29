import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:kelal_studio/core/render_engine/canvas_scene.dart';

/// The single, authoritative paint routine for a [CanvasScene].
///
/// PRD §5.6/§6.9: client-side rendering is the single authoritative
/// renderer — what the user sees in the live editor *is* the literal
/// exported artifact, because both call this exact function. There must
/// never be a second implementation (e.g. a server-side renderer, or a
/// simplified "preview-only" paint path) — the PRD's top-rated risk
/// ("preview doesn't match export") is a direct consequence of two
/// diverging implementations, and this class exists specifically to make
/// that divergence structurally impossible.
///
/// Do not add a parameter here that changes visual output between preview
/// and export (e.g. "isPreview: true" that skips a text layer) — if the
/// editor and export need to differ, that's a product decision to flag
/// (mobile/.claude/skills/flutter-architecture/SKILL.md), not a quiet
/// branch in this file.
abstract final class RenderEngine {
  static void paint(Canvas canvas, Size size, CanvasScene scene) {
    final scaleX = size.width / scene.canvasSize.width;
    final scaleY = size.height / scene.canvasSize.height;

    canvas
      ..save()
      ..scale(scaleX, scaleY);

    paintImage(
      canvas: canvas,
      rect: Offset.zero & scene.canvasSize,
      image: scene.backgroundImage,
      fit: BoxFit.cover,
    );

    // Compositing order: background -> logo -> text. **Logo below text is
    // a deliberate UX default, not a PRD-specified requirement** (§6.9/§6.5
    // don't say which wins if a text layer and the logo overlap) — a brand
    // logo is conventionally a corner watermark, and if a user-dragged
    // caption ever does overlap it, keeping the caption legible on top
    // matters more than keeping the watermark visible underneath, the same
    // reasoning most social-template tools apply. Flagged here as a
    // judgment call to revisit if the PRD is ever more specific.
    if (scene.logo != null) {
      _paintLogo(canvas, scene.canvasSize, scene.logo!);
    }

    for (final layer in scene.textLayers) {
      _paintTextLayer(canvas, scene.canvasSize, layer);
    }

    canvas.restore();
  }

  static void _paintLogo(Canvas canvas, Size canvasSize, LogoLayer logo) {
    final width = logo.normalizedWidth * canvasSize.width;
    // Height derives from the logo image's own aspect ratio (see
    // LogoLayer.normalizedWidth's doc comment) rather than a second
    // independently-stored normalized height, so a logo can never be
    // stretched out of its true proportions.
    final height = width * (logo.image.height / logo.image.width);
    final rect = Rect.fromLTWH(
      logo.normalizedOffset.dx * canvasSize.width,
      logo.normalizedOffset.dy * canvasSize.height,
      width,
      height,
    );
    paintImage(
      canvas: canvas,
      rect: rect,
      image: logo.image,
      fit: BoxFit.contain,
    );
  }

  static void _paintTextLayer(Canvas canvas, Size canvasSize, TextLayer layer) {
    final painter = TextPainter(
      text: TextSpan(text: layer.text, style: layer.style),
      textAlign: layer.textAlign,
      textDirection: TextDirection.ltr,
      // Ethiopic line-break opportunities per PRD §6.7: space, U+1361, U+1362
      // — never mid-syllable. Flutter's default line-breaker already treats
      // these as break points (they're Unicode word-separator/terminator
      // punctuation), so no custom LineBreaker is needed; verify against the
      // golden-image corpus in mobile/.claude/skills/flutter-ethiopic-typography
      // rather than assuming — this comment is the flag, not the proof.
    );
    final maxWidth = layer.normalizedMaxWidth * canvasSize.width;
    painter.layout(maxWidth: maxWidth);
    final offset = Offset(
      layer.normalizedOffset.dx * canvasSize.width,
      layer.normalizedOffset.dy * canvasSize.height,
    );
    painter.paint(canvas, offset);
  }

  /// Renders [scene] to PNG bytes at its full [CanvasScene.canvasSize] —
  /// used by `features/export`. Calls the exact same [paint] routine the
  /// live [CustomPainter] uses; see class doc.
  static Future<Uint8List> exportPng(CanvasScene scene) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas, scene.canvasSize, scene);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      scene.canvasSize.width.round(),
      scene.canvasSize.height.round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) {
      throw StateError('Failed to encode canvas scene to PNG.');
    }
    return byteData.buffer.asUint8List();
  }
}

/// [CustomPainter] wrapper for the live editor — thin adapter over
/// [RenderEngine.paint], intentionally with no logic of its own.
class CanvasScenePainter extends CustomPainter {
  const CanvasScenePainter(this.scene);

  final CanvasScene scene;

  @override
  void paint(Canvas canvas, Size size) =>
      RenderEngine.paint(canvas, size, scene);

  @override
  bool shouldRepaint(covariant CanvasScenePainter oldDelegate) =>
      !identical(oldDelegate.scene, scene);
}
