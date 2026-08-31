import 'dart:ui' as ui;

import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/data/services/network_image_decoder.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. `ImageGenerationBloc`
/// calls this use case, never `NetworkImageDecoder` directly, keeping the
/// "presentation calls use cases only" rule intact for this step too.
///
/// **Deliberately depends on the concrete [NetworkImageDecoder], not a
/// repository interface** — unlike every other use case in this codebase.
/// Every other use case's repository interface exists specifically to let
/// `data/` swap a real vs. fake implementation behind `Env.useMockApi`
/// (see mobile/.claude/skills/flutter-networking-data/SKILL.md). There is
/// no equivalent real/fake split for "decode these image bytes with
/// `dart:ui`" — it's deterministic client-side codec work, not a network
/// call whose *backend* varies; introducing an interface here would be
/// layering ceremony with no swap it actually enables. [ui.Image] itself
/// is a `dart:ui` type, same as `core/render_engine/canvas_scene.dart`'s
/// `CanvasScene`/`TextLayer` — this use case is the deliberately-flagged
/// bridge from a domain-pure `GenerationImageResult.imageUrl` to that
/// core/render_engine-typed world, not a claim that `dart:ui` belongs in
/// `domain/` generally.
@injectable
class DecodeGeneratedImageUseCase {
  DecodeGeneratedImageUseCase(this._decoder);

  final NetworkImageDecoder _decoder;

  Future<Result<Failure, ui.Image>> call(String imageUrl) =>
      _decoder.decode(imageUrl);
}
