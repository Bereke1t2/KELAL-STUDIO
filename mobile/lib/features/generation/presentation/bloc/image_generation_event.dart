import 'package:equatable/equatable.dart';

import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';

sealed class ImageGenerationEvent extends Equatable {
  const ImageGenerationEvent();
}

/// Dispatched when the user asks to turn a composed idea into a graphic —
/// carries the caption and chosen ratio snapshotted at submit time, mirrors
/// `GenerationRequested`'s "only dispatch on submit" pattern.
/// `brand_kit_id` is, same as `GenerationRequested`, not a field here —
/// resolved inside `ImageGenerationBloc`, except here a missing/failed
/// resolution is a real blocking error rather than an omittable optional
/// field (see the Bloc's doc comment; `GenerateImageRequest.brand_kit_id`
/// is required per mobile/api_contract/openapi.yaml).
final class ImageGenerationRequested extends ImageGenerationEvent {
  const ImageGenerationRequested({
    required this.captionEn,
    required this.aspectRatio,
  });

  final String captionEn;
  final GenerationAspectRatio aspectRatio;

  @override
  List<Object?> get props => [captionEn, aspectRatio];
}
