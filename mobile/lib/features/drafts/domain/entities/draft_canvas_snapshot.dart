import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';
import 'package:path_provider/path_provider.dart';

part 'draft_canvas_snapshot.freezed.dart';
part 'draft_canvas_snapshot.g.dart';

/// **Deliberate, flagged exception to `domain/`'s usual purity rule** (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md) — this file imports
/// `dart:ui`, `dart:io`, and `package:flutter/widgets.dart`
/// (`Offset`/`TextAlign`/`FontWeight`/`Color`), same class of exception
/// `features/generation/domain/usecases/decode_generated_image_usecase.dart`
/// already makes for `ui.Image`: `CanvasScene`/`TextLayer` (the thing this
/// class snapshots) are themselves `core/render_engine`-typed, carrying a
/// decoded `ui.Image` that can't be JSON-serialized as-is. A
/// `DraftCanvasSnapshot` exists specifically to be the JSON-serializable
/// stand-in for a `CanvasScene` that Drift's `Drafts.canvasStateJson`
/// column can actually store — that bridging job is unavoidably `dart:ui`-
/// and `dart:io`-shaped (decoding/re-encoding the background image,
/// reading/writing its PNG file), not a sign this class belongs in `data/`
/// instead: everything it does is pure data shaping with no network/DB
/// access of its own (that's `DraftRepositoryImpl`'s job).
@freezed
abstract class DraftCanvasSnapshot with _$DraftCanvasSnapshot {
  const factory DraftCanvasSnapshot({
    /// Absolute path to a PNG file under the app documents directory's
    /// `drafts/` subfolder, named `<localId>.png` — written once by
    /// [fromCanvasScene], read back by [toCanvasScene]. Storing a file
    /// path (not the raw bytes) keeps `Drafts.canvasStateJson` small and
    /// avoids holding a full-resolution image in memory just to persist
    /// the draft row itself.
    required String backgroundImagePath,
    required double canvasWidth,
    required double canvasHeight,
    required List<DraftTextLayerSnapshot> textLayers,

    /// Never the logo image itself — see [toCanvasScene]'s doc comment for
    /// why this alone isn't enough to rebuild a `LogoLayer` today.
    DraftLogoSnapshot? logo,
  }) = _DraftCanvasSnapshot;

  const DraftCanvasSnapshot._();

  factory DraftCanvasSnapshot.fromJson(Map<String, dynamic> json) =>
      _$DraftCanvasSnapshotFromJson(json);

  /// Builds a [DraftCanvasSnapshot] from a live [scene], including the
  /// PNG-encode-and-write side effect that makes this a `static
  /// Future<...>` factory-style method rather than a plain `const
  /// factory` — freezed factories can't be `async`.
  ///
  /// [localId] names the written file (`<localId>.png`) so repeated
  /// autosaves for the same editing session (see `DraftAutosaveCubit`,
  /// which reuses one `localId` for its whole session) overwrite the same
  /// file instead of accumulating one PNG per autosave tick.
  static Future<DraftCanvasSnapshot> fromCanvasScene(
    CanvasScene scene, {
    required String localId,
  }) async {
    final byteData = await scene.backgroundImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      // toByteData only returns null if the underlying image handle was
      // already disposed out from under this call — treat it the same as
      // any other unexpected local-storage failure so the caller (
      // `DraftAutosaveCubit`) has one failure path to handle, not two.
      throw StateError('Failed to encode CanvasScene.backgroundImage to PNG');
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final draftsDir = Directory('${documentsDir.path}/drafts');
    await draftsDir.create(recursive: true);
    final file = File('${draftsDir.path}/$localId.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    return DraftCanvasSnapshot(
      backgroundImagePath: file.path,
      canvasWidth: scene.canvasSize.width,
      canvasHeight: scene.canvasSize.height,
      textLayers: scene.textLayers
          .map(DraftTextLayerSnapshot.fromTextLayer)
          .toList(),
      logo: scene.logo == null
          ? null
          : DraftLogoSnapshot(
              dx: scene.logo!.normalizedOffset.dx,
              dy: scene.logo!.normalizedOffset.dy,
              normalizedWidth: scene.logo!.normalizedWidth,
            ),
    );
  }

  /// Rebuilds a live [CanvasScene] from this snapshot — the counterpart to
  /// [fromCanvasScene]. Redecodes [backgroundImagePath] via
  /// `dart:ui`'s `instantiateImageCodec` (a fresh decode, same as any
  /// other `ui.Image` in this codebase never being cached across app
  /// restarts) and rebuilds every [textLayers] entry back into a
  /// `TextLayer`.
  ///
  /// **[logo] is always dropped (`logo: null` on the returned scene) —
  /// this is a real, confirmed product gap, not a silent workaround.**
  /// Rebuilding a `LogoLayer` needs actual displayable image bytes for the
  /// *current* brand kit's logo, and no mechanism anywhere in this
  /// codebase can turn a `BrandKit.logoAssetId` into bytes today —
  /// `BrandKitRepository` only exposes `getBrandKit()` (id only, no
  /// display URL — see `BrandKit.logoAssetId`'s own doc comment and
  /// mobile/CLAUDE.md's "no display URL for an uploaded logo" contract
  /// gap) / `updateBrandKit()` / `uploadLogo()` (write-only, doesn't read
  /// bytes back). [brandKitRepository] is still threaded through and
  /// called here — the same use-case/repository call the rest of the app
  /// would make if the bytes-fetch step existed — so the moment that gap
  /// is closed, wiring the real `LogoLayer` construction in is a local
  /// change to this method, not a new call path to invent. Until then, a
  /// resumed draft simply loses its logo overlay rather than crashing or
  /// fabricating a placeholder image.
  Future<CanvasScene> toCanvasScene({
    required BrandKitRepository brandKitRepository,
  }) async {
    final bytes = await File(backgroundImagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    // See this method's doc comment above: this call exists to reach the
    // point where a real logo-bytes resolution *would* plug in, not
    // because its result is used below — `logo` stays `null` regardless
    // of what comes back here.
    await brandKitRepository.getBrandKit();

    // `logo` deliberately omitted — its default is already `null`, per
    // this method's doc comment above.
    return CanvasScene(
      backgroundImage: frame.image,
      canvasSize: Size(canvasWidth, canvasHeight),
      textLayers: textLayers.map((l) => l.toTextLayer()).toList(),
    );
  }
}

/// Enough of a `TextLayer` to reconstruct one — see
/// `core/render_engine/canvas_scene.dart`'s `TextLayer` for the live
/// (non-serializable) counterpart this mirrors field-by-field.
@freezed
abstract class DraftTextLayerSnapshot with _$DraftTextLayerSnapshot {
  const factory DraftTextLayerSnapshot({
    required String id,
    required String text,
    required double dx,
    required double dy,
    required double normalizedMaxWidth,
    required double fontSize,

    /// `FontWeight.value` (100-900), despite the field name — not an index
    /// into `FontWeight.values`. Named to match this branch's spec; see
    /// [toTextLayer] for the exact reconstruction.
    required int fontWeightIndex,

    /// `Color.toARGB32()` — `Color.value` is deprecated on this Flutter
    /// SDK, so that (not the deprecated getter) is what's stored here.
    required int colorValue,
    required int textAlignIndex,
  }) = _DraftTextLayerSnapshot;

  const DraftTextLayerSnapshot._();

  factory DraftTextLayerSnapshot.fromJson(Map<String, dynamic> json) =>
      _$DraftTextLayerSnapshotFromJson(json);

  factory DraftTextLayerSnapshot.fromTextLayer(TextLayer layer) {
    return DraftTextLayerSnapshot(
      id: layer.id,
      text: layer.text,
      dx: layer.normalizedOffset.dx,
      dy: layer.normalizedOffset.dy,
      normalizedMaxWidth: layer.normalizedMaxWidth,
      fontSize: layer.style.fontSize ?? 16,
      fontWeightIndex: (layer.style.fontWeight ?? FontWeight.normal).value,
      colorValue: (layer.style.color ?? const Color(0xFFFFFFFF)).toARGB32(),
      textAlignIndex: TextAlign.values.indexOf(layer.textAlign),
    );
  }

  TextLayer toTextLayer() {
    return TextLayer(
      id: id,
      text: text,
      normalizedOffset: Offset(dx, dy),
      normalizedMaxWidth: normalizedMaxWidth,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.values.firstWhere(
          (w) => w.value == fontWeightIndex,
          orElse: () => FontWeight.normal,
        ),
        color: Color(colorValue),
        // Fixed at AppTypography.lineHeightMultiplier (1.55), never
        // captured as per-layer data — mobile/.claude/skills/
        // flutter-ethiopic-typography/SKILL.md requires this line-height
        // is never overridden per-style, so the correct fix here is to
        // always apply the app-wide constant on reconstruction, not to
        // round-trip whatever height the live TextStyle happened to carry
        // (RenderEngine.paint uses this style verbatim — see its own
        // `TextSpan(text: layer.text, style: layer.style)` — so omitting
        // this entirely would silently regress a resumed draft's text to
        // Flutter's default line-height, a real Ethiopic-rendering bug).
        height: AppTypography.lineHeightMultiplier,
      ),
      textAlign: TextAlign.values[textAlignIndex],
    );
  }
}

/// Enough of a `LogoLayer` to reconstruct its position/size — never the
/// image itself (see `DraftCanvasSnapshot.logo`'s doc comment for why
/// that's never actually usable on resume today regardless).
@freezed
abstract class DraftLogoSnapshot with _$DraftLogoSnapshot {
  const factory DraftLogoSnapshot({
    required double dx,
    required double dy,
    required double normalizedWidth,
  }) = _DraftLogoSnapshot;

  factory DraftLogoSnapshot.fromJson(Map<String, dynamic> json) =>
      _$DraftLogoSnapshotFromJson(json);
}
