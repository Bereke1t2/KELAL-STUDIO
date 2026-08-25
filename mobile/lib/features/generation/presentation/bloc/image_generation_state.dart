import 'package:equatable/equatable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';

sealed class ImageGenerationState extends Equatable {
  const ImageGenerationState();

  @override
  List<Object?> get props => const [];
}

final class ImageGenerationInitial extends ImageGenerationState {
  const ImageGenerationInitial();
}

final class ImageGenerationInProgress extends ImageGenerationState {
  const ImageGenerationInProgress();
}

/// Client-side, pre-flight blocking state — reached *without* ever calling
/// `/generate/image` — when no brand kit could be resolved for the current
/// account. Deliberately not an [ImageGenerationFailure]/[ApiFailure]:
/// `ApiErrorType`'s taxonomy (PRD §11) models typed *server* error
/// responses, and this never reaches the server at all — collapsing it
/// into, say, `ApiErrorType.validationError` would misrepresent a
/// client-side precondition as a backend rejection. See
/// `ImageGenerationBloc`'s doc comment for why this field is required
/// (unlike `GenerationRequested`'s optional `brand_kit_id`) and therefore
/// worth a distinct blocking state instead of the "fall back to omitting
/// it" behavior `GenerationBloc` uses for text.
final class ImageGenerationBrandKitRequired extends ImageGenerationState {
  const ImageGenerationBrandKitRequired();
}

/// [scene] is a ready-to-edit `CanvasScene` (decoded background already in
/// memory, sized to [result]'s own `width`/`height` — not a hardcoded
/// `GenerationAspectRatio.canvasSize` guess) that `features/canvas_editor` can be
/// initialized from directly.
final class ImageGenerationSuccess extends ImageGenerationState {
  const ImageGenerationSuccess({required this.scene, required this.result});

  final CanvasScene scene;
  final GenerationImageResult result;

  @override
  List<Object?> get props => [scene, result];
}

/// Carries the full [ApiFailure] — same reasoning as `GenerationFailure`'s
/// doc comment (`presentation/bloc/generation_state.dart`).
final class ImageGenerationFailure extends ImageGenerationState {
  const ImageGenerationFailure(this.failure);
  final ApiFailure failure;

  @override
  List<Object?> get props => [
    failure.type,
    failure.message,
    failure.resetsAt,
    failure.moderationReason,
  ];
}
