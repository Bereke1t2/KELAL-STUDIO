/// Canvas "safe zone" obstruction bands — the top/bottom regions of a
/// generated graphic that a target platform's own UI chrome (profile
/// header, caption/action bar, etc.) is likely to draw over once posted.
///
/// **OQ-06 (pending): these are flat, PRD §6.5 placeholder numbers, not a
/// real per-platform table.** The PRD names per-platform safe-zone
/// percentages as still-undefined (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's "Canvas safe
/// zones" open-question row: "Don't invent numbers; ask for the source or
/// treat as a visible TODO with a conservative placeholder, clearly
/// marked"). §6.5 does give one flat top-10%/bottom-15% figure, so that's
/// what's encoded here — a single conservative band applied uniformly
/// regardless of destination platform (Instagram/TikTok/Telegram each
/// almost certainly obstruct a different actual area), not a resolution of
/// OQ-06. Replace with the real per-platform table if/when the PRD
/// supplies one; every call site below is a call site that table would
/// need to reach too.
abstract final class SafeZoneConstants {
  /// Fraction of the scene's `canvasSize` height, measured from the top,
  /// treated as obstructed.
  static const double topObstructionFraction = 0.10;

  /// Fraction of the scene's `canvasSize` height, measured from the
  /// bottom, treated as obstructed.
  static const double bottomObstructionFraction = 0.15;

  /// Clamps a text layer's normalized offset dy so the layer's top edge
  /// never sits inside either obstruction band, given an estimate of how
  /// tall the layer renders as a fraction of canvas height
  /// ([layerHeightFraction]).
  ///
  /// **Clamps the anchor point, not a measured bounding box.** A fully
  /// correct clamp would need the text's actual painted height (a
  /// `TextPainter.layout()` pass, mirroring
  /// `RenderEngine._paintTextLayer`) to guarantee the *whole* box clears
  /// the band, including wrapped multi-line captions. Running a full text
  /// layout inside what's meant to be a cheap, synchronous, widget-free
  /// gesture-math function (see `features/canvas_editor`'s
  /// `CanvasEditorBloc` doc comment) was judged not worth the cost here;
  /// [layerHeightFraction] is instead a single-line estimate the caller
  /// derives from the layer's font size. This is directionally correct
  /// and prevents the common case, but is a documented approximation, not
  /// a pixel-exact guarantee for long, wrapped captions — flagged rather
  /// than silently assumed exact.
  static double clampNormalizedOffsetY({
    required double dy,
    required double layerHeightFraction,
  }) {
    const minY = topObstructionFraction;
    final maxY = 1.0 - bottomObstructionFraction - layerHeightFraction;
    // Degenerate case: the layer is taller than the entire safe area
    // (e.g. a very large font on a small canvas) — pin to the top of the
    // safe area rather than producing an inverted/negative range.
    if (maxY < minY) return minY;
    return dy.clamp(minY, maxY);
  }
}
