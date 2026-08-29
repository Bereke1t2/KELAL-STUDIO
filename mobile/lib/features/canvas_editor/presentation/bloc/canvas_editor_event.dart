import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Offset, Size;

import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';

sealed class CanvasEditorEvent extends Equatable {
  const CanvasEditorEvent();
}

/// Dispatched once when the canvas editor screen mounts, carrying the
/// `CanvasScene` built from a successful `ImageGenerationSuccess` (see
/// `features/generation/presentation/bloc/image_generation_bloc.dart`).
final class CanvasEditorSceneLoaded extends CanvasEditorEvent {
  const CanvasEditorSceneLoaded(this.scene);
  final CanvasScene scene;

  @override
  List<Object?> get props => [scene];
}

/// `null` deselects (e.g. tapping empty canvas space).
final class CanvasEditorLayerSelected extends CanvasEditorEvent {
  const CanvasEditorLayerSelected(this.layerId);
  final String? layerId;

  @override
  List<Object?> get props => [layerId];
}

/// [screenDelta] and [boxSize] are both in on-screen logical pixels — the
/// `CustomPaint` box's own size, **not** `CanvasScene.canvasSize`. See
/// `CanvasEditorBloc.normalizedDragDelta`'s doc comment for why the
/// conversion needs the box size, not the full-resolution canvas size.
final class CanvasEditorLayerDragUpdated extends CanvasEditorEvent {
  const CanvasEditorLayerDragUpdated({
    required this.layerId,
    required this.screenDelta,
    required this.boxSize,
  });

  final String layerId;
  final Offset screenDelta;
  final Size boxSize;

  @override
  List<Object?> get props => [layerId, screenDelta, boxSize];
}

/// [scaleFactor] is multiplicative (e.g. `ScaleUpdateDetails.scale`, ~1.0
/// at gesture start) — applied to the layer's current
/// `TextLayer.normalizedMaxWidth`, not an absolute value. See
/// `CanvasEditorBloc`'s doc comment for why "resize" mutates the text
/// box's width rather than a font-size scale.
final class CanvasEditorLayerScaled extends CanvasEditorEvent {
  const CanvasEditorLayerScaled({
    required this.layerId,
    required this.scaleFactor,
  });

  final String layerId;
  final double scaleFactor;

  @override
  List<Object?> get props => [layerId, scaleFactor];
}

/// Dispatched when the tap-to-edit bottom sheet (`AppTextField` +
/// `showAppBottomSheet`) is confirmed.
final class CanvasEditorLayerTextChanged extends CanvasEditorEvent {
  const CanvasEditorLayerTextChanged({
    required this.layerId,
    required this.text,
  });

  final String layerId;
  final String text;

  @override
  List<Object?> get props => [layerId, text];
}

/// Adds a new, empty text layer — a no-op past the PRD's 1-2 cap (see
/// `CanvasEditorReady.canAddTextLayer`, which the UI should use to disable
/// the add affordance rather than relying on this being silently ignored).
final class CanvasEditorLayerAdded extends CanvasEditorEvent {
  const CanvasEditorLayerAdded();

  @override
  List<Object?> get props => const [];
}

final class CanvasEditorLayerRemoved extends CanvasEditorEvent {
  const CanvasEditorLayerRemoved(this.layerId);
  final String layerId;

  @override
  List<Object?> get props => [layerId];
}

/// Changes `CanvasScene.canvasSize` to [aspectRatio]'s target size —
/// re-crops the same already-decoded `backgroundImage` via
/// `RenderEngine.paint`'s existing `BoxFit.cover`, no redecode, no new
/// `/generate/image` call. See `CanvasEditorBloc`'s doc comment for the
/// full reasoning behind putting the aspect-ratio selector here instead of
/// the composer.
final class CanvasEditorAspectRatioChanged extends CanvasEditorEvent {
  const CanvasEditorAspectRatioChanged(this.aspectRatio);
  final GenerationAspectRatio aspectRatio;

  @override
  List<Object?> get props => [aspectRatio];
}
