import 'package:equatable/equatable.dart';

/// Pure-Dart domain entity — no Flutter, no json, no dio imports here (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule). Mirrors `GenerateImageResponse` in
/// mobile/api_contract/openapi.yaml (`asset_id`, `image_url`, `width`,
/// `height`).
///
/// Deliberately carries a URL, not a decoded `ui.Image` — decoding is a
/// `dart:ui`/rendering concern that belongs on the far side of this
/// boundary (see `features/generation/data/services/network_image_decoder.dart`
/// and `DecodeGeneratedImageUseCase`'s doc comment for exactly where that
/// step lives and why it's not folded into this entity or
/// `GenerateImageUseCase` itself).
class GenerationImageResult extends Equatable {
  const GenerationImageResult({
    required this.assetId,
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  final String assetId;
  final String imageUrl;
  final int width;
  final int height;

  @override
  List<Object?> get props => [assetId, imageUrl, width, height];
}
