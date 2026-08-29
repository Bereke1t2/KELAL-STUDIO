import 'package:equatable/equatable.dart';

import 'package:kelal_studio/core/render_engine/canvas_scene.dart';

sealed class CanvasEditorState extends Equatable {
  const CanvasEditorState();

  @override
  List<Object?> get props => const [];
}

/// Before `CanvasEditorSceneLoaded` has been dispatched — the editor screen
/// should never actually render its canvas in this state; it's only
/// reachable for the brief span between `BlocProvider` construction and
/// the mount-time `add(CanvasEditorSceneLoaded(...))`.
final class CanvasEditorInitial extends CanvasEditorState {
  const CanvasEditorInitial();
}

final class CanvasEditorReady extends CanvasEditorState {
  const CanvasEditorReady({required this.scene, this.selectedLayerId});

  final CanvasScene scene;

  /// `null` when no text layer is currently selected (e.g. right after
  /// load, or after tapping empty canvas space).
  final String? selectedLayerId;

  /// PRD §6.9: "1-2 editable text layers."
  static const maxTextLayers = 2;

  bool get canAddTextLayer => scene.textLayers.length < maxTextLayers;

  /// [clearSelection] exists because `selectedLayerId` is itself nullable
  /// — a plain `selectedLayerId ?? this.selectedLayerId` `copyWith`
  /// (`CanvasScene.copyWith`'s pattern) couldn't express "explicitly
  /// deselect," only "leave it alone." Mirrors the same problem
  /// `CanvasScene.copyWith`'s doc comment flags for `logo`, resolved here
  /// (rather than left as a known gap) since deselection is a real,
  /// reachable action in this Bloc (`CanvasEditorLayerSelected(null)`).
  CanvasEditorReady copyWith({
    CanvasScene? scene,
    String? selectedLayerId,
    bool clearSelection = false,
  }) {
    return CanvasEditorReady(
      scene: scene ?? this.scene,
      selectedLayerId: clearSelection
          ? null
          : (selectedLayerId ?? this.selectedLayerId),
    );
  }

  @override
  List<Object?> get props => [scene, selectedLayerId];
}
