import 'package:equatable/equatable.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';

sealed class ExportEvent extends Equatable {
  const ExportEvent();

  @override
  List<Object?> get props => const [];
}

/// Renders [scene] via `RenderEngine.exportPng` and writes the result to
/// the device gallery.
final class ExportGallerySaveRequested extends ExportEvent {
  const ExportGallerySaveRequested(this.scene);

  final CanvasScene scene;

  @override
  List<Object?> get props => [scene];
}

/// Renders [scene] via `RenderEngine.exportPng` and hands the result (plus
/// optional [captionText]) to the OS Share Sheet.
final class ExportShareRequested extends ExportEvent {
  const ExportShareRequested({required this.scene, this.captionText});

  final CanvasScene scene;
  final String? captionText;

  @override
  List<Object?> get props => [scene, captionText];
}
