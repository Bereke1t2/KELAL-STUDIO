import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/render_engine/safe_zone_constants.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_event.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_state.dart';
import 'package:uuid/uuid.dart';

/// Owns the `CanvasScene` being edited plus editor-only UI state (selected
/// layer). No use case/repository dependency at all — unlike every other
/// Bloc in this codebase, every event this Bloc handles is a synchronous,
/// local mutation of already-in-memory state (drag/resize/add/remove/
/// select/retext a text layer, or swap the target aspect ratio). There is
/// no network call, no `drift` write, no `await` anywhere in any handler
/// below.
///
/// **Transformer choice: `concurrent()`, explicit, for every event.** This
/// looks like it should default to `restartable()` at first glance — PRD
/// §6.9's "edit against a downscaled proxy" guidance and
/// mobile/.claude/skills/flutter-state-management/SKILL.md's own example
/// ("canvas preview updates as a slider/drag moves") both specifically
/// name a canvas drag as the paradigm case for `restartable()`. But that
/// guidance is about *cancelling a stale in-flight async recompute* — it
/// presumes the handler does non-trivial async work per event (a redecode,
/// a network refetch) that a newer event should be allowed to interrupt.
/// Every handler here is a synchronous `Offset`/`double`/`String`
/// computation with no `async`/`await` — Dart's single-threaded event loop
/// already guarantees one handler's synchronous body runs to completion
/// before the next queued event's handler starts, regardless of which
/// `bloc_concurrency` transformer is attached, because there is no
/// `await` point for a second event's handler to interleave at. Attaching
/// `restartable()`/`droppable()` here wouldn't change behavior, only imply
/// (incorrectly) that there's an async race being guarded against.
/// `concurrent()` is used explicitly (never the implicit default — see
/// mobile/.claude/skills/flutter-state-management/SKILL.md's "Only use
/// this by writing `transformer: concurrent()` explicitly, so it's
/// visibly a decision in code review") specifically to make that
/// "verified, not skipped" conclusion visible rather than silently
/// omitting the argument.
@injectable
class CanvasEditorBloc extends Bloc<CanvasEditorEvent, CanvasEditorState> {
  CanvasEditorBloc() : super(const CanvasEditorInitial()) {
    on<CanvasEditorSceneLoaded>(_onSceneLoaded, transformer: concurrent());
    on<CanvasEditorLayerSelected>(_onLayerSelected, transformer: concurrent());
    on<CanvasEditorLayerDragUpdated>(
      _onLayerDragUpdated,
      transformer: concurrent(),
    );
    on<CanvasEditorLayerScaled>(_onLayerScaled, transformer: concurrent());
    on<CanvasEditorLayerTextChanged>(
      _onLayerTextChanged,
      transformer: concurrent(),
    );
    on<CanvasEditorLayerAdded>(_onLayerAdded, transformer: concurrent());
    on<CanvasEditorLayerRemoved>(_onLayerRemoved, transformer: concurrent());
    on<CanvasEditorAspectRatioChanged>(
      _onAspectRatioChanged,
      transformer: concurrent(),
    );
  }

  static const _uuid = Uuid();

  /// A freshly-added layer's text-box width, as a fraction of canvas
  /// width — generous enough for a short caption without a resize gesture
  /// being mandatory. Fixed: a pinch resizes font size now (see
  /// [_minFontSize]/[_maxFontSize] below), not this box width, so there's
  /// no corresponding min/max pair to clamp it against post-creation.
  static const _defaultNormalizedMaxWidth = 0.8;

  /// A freshly-added layer's starting font size, in the same raw-pixel
  /// units `RenderEngine` paints in (i.e. canvas-space pixels, not screen
  /// logical pixels). `AppTypography.body` (16) was the previous default —
  /// that's a *screen UI* reading size, sized for a phone held at arm's
  /// length, not a caption painted onto a 1080px-wide exported image; at
  /// 16px on a 1080px canvas a caption is under 2% of the image height and
  /// reads as near-invisible. 64px (~6% of a 1080-wide canvas) matches the
  /// caption sizes typical social-template tools (Instagram/Canva) default
  /// to on a same-resolution canvas.
  static const _defaultCanvasFontSize = 64.0;

  /// Pinch-to-resize clamp range for `TextLayer.style.fontSize`, in the
  /// same canvas-space pixel units as [_defaultCanvasFontSize] — small
  /// enough to still be a deliberate caption size (not screen-UI-small),
  /// large enough that a single word can't swallow the whole canvas.
  static const _minFontSize = 24.0;
  static const _maxFontSize = 220.0;

  void _onSceneLoaded(
    CanvasEditorSceneLoaded event,
    Emitter<CanvasEditorState> emit,
  ) {
    emit(CanvasEditorReady(scene: event.scene));
  }

  void _onLayerSelected(
    CanvasEditorLayerSelected event,
    Emitter<CanvasEditorState> emit,
  ) {
    final current = state;
    if (current is! CanvasEditorReady) return;
    emit(
      event.layerId == null
          ? current.copyWith(clearSelection: true)
          : current.copyWith(selectedLayerId: event.layerId),
    );
  }

  /// Converts an on-screen drag delta into a normalized (0..1 of canvas
  /// size) delta. Deliberately divides by [boxSize] — the live
  /// `CustomPaint` box's actual on-screen size — never
  /// `CanvasScene.canvasSize` (the full-resolution export target, e.g.
  /// 1080x1080). The editor paints the same full-res scene scaled down
  /// into a smaller box (see `canvas_scene.dart`'s doc comment on
  /// `canvasSize`); a screen pixel and a canvas pixel are different units,
  /// and this is the one piece of "downscaled proxy" math PRD §6.9 and
  /// mobile/.claude/skills/flutter-performance/SKILL.md actually require
  /// for interactive editing — not a second decoded bitmap (there is
  /// none), just this conversion.
  @visibleForTesting
  static Offset normalizedDragDelta({
    required Offset screenDelta,
    required Size boxSize,
  }) {
    if (boxSize.width <= 0 || boxSize.height <= 0) return Offset.zero;
    return Offset(
      screenDelta.dx / boxSize.width,
      screenDelta.dy / boxSize.height,
    );
  }

  /// Single-line estimate of a text layer's rendered height, as a fraction
  /// of canvas height — see `SafeZoneConstants.clampNormalizedOffsetY`'s
  /// doc comment for why this is an estimate (font size only, no
  /// `TextPainter` layout pass) rather than an exact measurement. Not
  /// test-only: `CanvasEditorPage`'s draggable-layer hit-box sizing reuses
  /// this exact estimate too, so the interactive touch target and the
  /// safe-zone clamp agree on "how tall is this layer" rather than
  /// maintaining two separate guesses.
  static double estimateLayerHeightFraction(TextLayer layer, Size canvasSize) {
    if (canvasSize.height <= 0) return 0;
    final fontSize = layer.style.fontSize ?? AppTypography.body.fontSize!;
    final lineHeight = fontSize * AppTypography.lineHeightMultiplier;
    return lineHeight / canvasSize.height;
  }

  void _onLayerDragUpdated(
    CanvasEditorLayerDragUpdated event,
    Emitter<CanvasEditorState> emit,
  ) {
    final current = state;
    if (current is! CanvasEditorReady) return;
    final index = current.scene.textLayers.indexWhere(
      (l) => l.id == event.layerId,
    );
    if (index == -1) return;
    final layer = current.scene.textLayers[index];

    final delta = normalizedDragDelta(
      screenDelta: event.screenDelta,
      boxSize: event.boxSize,
    );
    final rawOffset = layer.normalizedOffset + delta;

    // X: kept inside [0, 1 - normalizedMaxWidth] so the text box never
    // runs off either canvas edge — a plain canvas-bounds clamp, not a
    // safe-zone concern.
    final maxX = (1.0 - layer.normalizedMaxWidth).clamp(0.0, 1.0);
    final clampedX = rawOffset.dx.clamp(0.0, maxX);

    // Y: clamped live, during the drag itself, so the user never sees the
    // layer snap back at export time (this branch's documented
    // clamp-timing decision — see the report for the full reasoning).
    final heightFraction = estimateLayerHeightFraction(
      layer,
      current.scene.canvasSize,
    );
    final clampedY = SafeZoneConstants.clampNormalizedOffsetY(
      dy: rawOffset.dy,
      layerHeightFraction: heightFraction,
    );

    final updatedLayer = layer.copyWith(
      normalizedOffset: Offset(clampedX, clampedY),
    );
    final updatedLayers = [...current.scene.textLayers];
    updatedLayers[index] = updatedLayer;

    emit(
      current.copyWith(
        scene: current.scene.copyWith(textLayers: updatedLayers),
      ),
    );
  }

  /// "Resize" mutates [TextLayer.style]'s `fontSize`, clamped to
  /// [_minFontSize]/[_maxFontSize] — a pinch on a text layer now behaves
  /// like the text-resize gesture in Instagram/Canva-style editors, rather
  /// than only rewrapping the box at a fixed font size. `normalizedMaxWidth`
  /// (the wrap box) is left alone; a user who wants a narrower wrap can
  /// still edit the text itself to force a line break.
  ///
  /// After changing the font size, the layer's `normalizedOffset.dy` is
  /// re-clamped via `SafeZoneConstants.clampNormalizedOffsetY` using the
  /// *new* size's height estimate — otherwise enlarging a layer already
  /// near the top/bottom of the canvas could push it into (or past) an
  /// obstruction band without the user ever dragging it there.
  void _onLayerScaled(
    CanvasEditorLayerScaled event,
    Emitter<CanvasEditorState> emit,
  ) {
    final current = state;
    if (current is! CanvasEditorReady) return;
    final index = current.scene.textLayers.indexWhere(
      (l) => l.id == event.layerId,
    );
    if (index == -1) return;
    final layer = current.scene.textLayers[index];

    final currentFontSize = layer.style.fontSize ?? _defaultCanvasFontSize;
    final newFontSize = (currentFontSize * event.scaleFactor).clamp(
      _minFontSize,
      _maxFontSize,
    );
    final newStyle = layer.style.copyWith(fontSize: newFontSize);

    final newHeightFraction = estimateLayerHeightFraction(
      layer.copyWith(style: newStyle),
      current.scene.canvasSize,
    );
    final clampedY = SafeZoneConstants.clampNormalizedOffsetY(
      dy: layer.normalizedOffset.dy,
      layerHeightFraction: newHeightFraction,
    );

    final updatedLayer = layer.copyWith(
      style: newStyle,
      normalizedOffset: Offset(layer.normalizedOffset.dx, clampedY),
    );
    final updatedLayers = [...current.scene.textLayers];
    updatedLayers[index] = updatedLayer;

    emit(
      current.copyWith(
        scene: current.scene.copyWith(textLayers: updatedLayers),
      ),
    );
  }

  void _onLayerTextChanged(
    CanvasEditorLayerTextChanged event,
    Emitter<CanvasEditorState> emit,
  ) {
    final current = state;
    if (current is! CanvasEditorReady) return;
    final index = current.scene.textLayers.indexWhere(
      (l) => l.id == event.layerId,
    );
    if (index == -1) return;

    final updatedLayer = current.scene.textLayers[index].copyWith(
      text: event.text,
    );
    final updatedLayers = [...current.scene.textLayers];
    updatedLayers[index] = updatedLayer;

    emit(
      current.copyWith(
        scene: current.scene.copyWith(textLayers: updatedLayers),
      ),
    );
  }

  void _onLayerAdded(
    CanvasEditorLayerAdded event,
    Emitter<CanvasEditorState> emit,
  ) {
    final current = state;
    if (current is! CanvasEditorReady) return;
    // Silent no-op past the cap — see CanvasEditorLayerAdded's doc
    // comment: the UI is expected to disable the add affordance via
    // `canAddTextLayer` rather than this event ever firing at the cap in
    // practice, but the Bloc still guards it defensively.
    if (!current.canAddTextLayer) return;

    // Stack successive layers a little lower than the previous one so a
    // 2nd added layer isn't invisible directly underneath the 1st;
    // clamped into the safe area same as a drag would be.
    final baseY = 0.35 + (current.scene.textLayers.length * 0.15);
    final newLayer = TextLayer(
      id: _uuid.v4(),
      // Deliberately empty, not a placeholder phrase like "Your caption
      // here" — this is user-generated *canvas content* that ships in the
      // exported graphic if left untouched, not app-interface chrome, so
      // it isn't an `AppLocalizations` string (see
      // mobile/.claude/skills/flutter-ethiopic-typography/SKILL.md's
      // scope — that's about the app's own UI, not user content) and
      // baking in an English default risked shipping stray English text
      // into an Amharic-composed graphic. `CanvasEditorPage` opens the
      // tap-to-edit sheet immediately for a newly-added (empty) layer so
      // this is never left visibly blank in practice.
      text: '',
      normalizedOffset: Offset(
        0.1,
        SafeZoneConstants.clampNormalizedOffsetY(
          dy: baseY,
          layerHeightFraction:
              _defaultCanvasFontSize *
              AppTypography.lineHeightMultiplier /
              current.scene.canvasSize.height,
        ),
      ),
      normalizedMaxWidth: _defaultNormalizedMaxWidth,
      // Font family/weight/line-height still come from AppTypography.body
      // (the Ethiopic-safe values `flutter-ethiopic-typography` governs) —
      // only the size is overridden to [_defaultCanvasFontSize], a
      // canvas-space size rather than a screen-UI reading size. See that
      // constant's doc comment for why 16 (AppTypography.body's own size)
      // read as near-invisible once painted onto a 1080px canvas.
      style: AppTypography.body.copyWith(
        fontSize: _defaultCanvasFontSize,
        color: const Color(0xFFFFFFFF),
      ),
    );

    emit(
      current.copyWith(
        scene: current.scene.copyWith(
          textLayers: [...current.scene.textLayers, newLayer],
        ),
        selectedLayerId: newLayer.id,
      ),
    );
  }

  void _onLayerRemoved(
    CanvasEditorLayerRemoved event,
    Emitter<CanvasEditorState> emit,
  ) {
    final current = state;
    if (current is! CanvasEditorReady) return;
    final updatedLayers = current.scene.textLayers
        .where((l) => l.id != event.layerId)
        .toList();

    emit(
      CanvasEditorReady(
        scene: current.scene.copyWith(textLayers: updatedLayers),
        selectedLayerId: current.selectedLayerId == event.layerId
            ? null
            : current.selectedLayerId,
      ),
    );
  }

  void _onAspectRatioChanged(
    CanvasEditorAspectRatioChanged event,
    Emitter<CanvasEditorState> emit,
  ) {
    final current = state;
    if (current is! CanvasEditorReady) return;
    emit(
      current.copyWith(
        scene: current.scene.copyWith(canvasSize: event.aspectRatio.canvasSize),
      ),
    );
    // No re-clamping of existing text layers on ratio change: normalized
    // coordinates and SafeZoneConstants' fractions are both already
    // resolution-independent (a fraction of *whichever* canvas height is
    // current), so a layer that was safely positioned under the old ratio
    // stays safely positioned under the new one without adjustment.
  }
}
