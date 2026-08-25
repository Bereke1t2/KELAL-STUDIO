import 'dart:ui' show Size;

/// Mirrors `GenerateImageRequest.aspect_ratio`'s enum in
/// mobile/api_contract/openapi.yaml (`["1:1", "4:5"]`) — that schema's own
/// inline comment: "OQ-02 in the PRD is open (2 vs 3 ratios) — 1:1 and 4:5
/// are the two the PRD's P0 list agrees on; 9:16 is NOT enabled here
/// pending that decision. Flag, don't silently add it." This enum
/// deliberately has no `nineBySixteen` member — adding one is a product
/// decision (OQ-02), not a client-side convenience.
///
/// Imports `dart:ui` for [Size] only (not `package:flutter`) — kept as
/// close to domain-pure as the rest of this codebase's pattern allows;
/// `core/render_engine/canvas_scene.dart` (which [canvasSize] feeds) is
/// itself built on `dart:ui` types, so this enum speaking the same
/// currency avoids a redundant conversion type at the boundary.
enum GenerationAspectRatio {
  oneToOne,
  fourToFive;

  /// The exact wire value this maps to — see `ContentPlatform.wireValue`'s
  /// doc comment (`features/generation/domain/entities/content_platform.dart`)
  /// for why this isn't derived from `.name`.
  String get wireValue => switch (this) {
    GenerationAspectRatio.oneToOne => '1:1',
    GenerationAspectRatio.fourToFive => '4:5',
  };

  /// The `CanvasScene.canvasSize` this ratio maps to for a *newly created*
  /// scene, before a real `GenerateImageResponse.width`/`height` is known
  /// (e.g. seeding `CanvasEditorAspectRatioChanged`'s target size — see
  /// `features/canvas_editor`). 1080 is chosen as a realistic full-res
  /// social-image width (matches Instagram's own long-standing upload
  /// guidance for a 1:1/4:5 post), not a value pulled from the OpenAPI
  /// contract (`GenerateImageResponse` doesn't constrain width/height, it
  /// just echoes back whatever the backend/fake produced — see
  /// `GenerationImageResult`'s doc comment). Once a real
  /// `GenerateImageResponse` is in hand, its own `width`/`height` is what
  /// actually seeds the initial `CanvasScene.canvasSize` — this getter is
  /// only used when the user changes ratio *inside* the editor afterward,
  /// re-cropping the same already-decoded background via
  /// `RenderEngine.paint`'s existing `BoxFit.cover` (no redecode, no new
  /// network call — see `CanvasEditorBloc`'s doc comment).
  Size get canvasSize => switch (this) {
    GenerationAspectRatio.oneToOne => const Size(1080, 1080),
    GenerationAspectRatio.fourToFive => const Size(1080, 1350),
  };
}
