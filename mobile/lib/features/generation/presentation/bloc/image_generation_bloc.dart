import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/decode_generated_image_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_image_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/image_generation_state.dart';

/// [ImageGenerationRequested] uses `droppable()`, deliberately re-derived
/// for this Bloc rather than copied from `GenerationBloc` (its text-only
/// sibling) — see mobile/.claude/skills/flutter-state-management/SKILL.md's
/// transformer table.
///
/// The reasoning tracks `GenerationBloc`'s almost exactly (this call also
/// consumes a scarce, per-user quota unit on every request that reaches
/// the backend — PRD §6.14 tracks `image_calls_used/limit` as its own
/// quota dimension, separate from `text_calls_*` — and a double-tap must
/// not silently burn two), with one addition specific to this Bloc: the
/// full `_onRequested` handler doesn't end when `/generate/image`
/// responds, it continues into [DecodeGeneratedImageUseCase] to actually
/// fetch and decode the returned `image_url` before emitting success.
/// `droppable()` covers that entire span, not just the network call — a
/// second `ImageGenerationRequested` fired while the first request is
/// still mid-decode is exactly as unsafe to double-run as one fired
/// mid-network-call, so the transformer needs to guard the whole handler,
/// which it does simply by virtue of wrapping the one `async` function.
///
/// **Not `BrandKitBloc`'s `droppable()` copied wholesale either** — same
/// caution `GenerationBloc`'s doc comment gives: the shape looks similar,
/// but this Bloc's stakes (quota + a full network image fetch, not a
/// profile-field `PUT`) are what actually justify the choice here.
@injectable
class ImageGenerationBloc
    extends Bloc<ImageGenerationEvent, ImageGenerationState> {
  ImageGenerationBloc(
    this._generateImageUseCase,
    this._getBrandKitUseCase,
    this._decodeGeneratedImageUseCase,
  ) : super(const ImageGenerationInitial()) {
    on<ImageGenerationRequested>(_onRequested, transformer: droppable());
  }

  final GenerateImageUseCase _generateImageUseCase;
  final GetBrandKitUseCase _getBrandKitUseCase;
  final DecodeGeneratedImageUseCase _decodeGeneratedImageUseCase;

  Future<void> _onRequested(
    ImageGenerationRequested event,
    Emitter<ImageGenerationState> emit,
  ) async {
    emit(const ImageGenerationInProgress());

    // `brand_kit_id` is REQUIRED on `GenerateImageRequest` (see
    // mobile/api_contract/openapi.yaml and `GenerationRepository
    // .generateImage`'s doc comment) — unlike `GenerationBloc`'s
    // "optional, fall back to omitting it" resolution of the same brand
    // kit, a failure (or absence) here must block the call outright with a
    // real, user-facing error rather than silently proceeding without an
    // id the backend will reject anyway.
    final brandKitResult = await _getBrandKitUseCase();
    final brandKitId = brandKitResult.valueOrNull?.id;
    if (brandKitId == null) {
      emit(const ImageGenerationBrandKitRequired());
      return;
    }

    final generateResult = await _generateImageUseCase(
      captionEn: event.captionEn,
      aspectRatio: event.aspectRatio,
      brandKitId: brandKitId,
    );

    await generateResult.when(
      ok: (imageResult) async {
        final decodeResult = await _decodeGeneratedImageUseCase(
          imageResult.imageUrl,
        );
        emit(
          decodeResult.when(
            ok: (image) => ImageGenerationSuccess(
              result: imageResult,
              scene: CanvasScene(
                backgroundImage: image,
                // Sized from the real response, not a hardcoded
                // GenerationAspectRatio.canvasSize guess — see
                // ImageGenerationSuccess's doc comment.
                canvasSize: Size(
                  imageResult.width.toDouble(),
                  imageResult.height.toDouble(),
                ),
                // No logo layer wired here — BrandKit
                // (features/brand_kit/domain/entities/brand_kit.dart)
                // exposes only `logoAssetId`, not a display URL (see
                // mobile/CLAUDE.md's already-flagged Brand Kit contract
                // gap: "no display URL for an uploaded logo"), so there
                // is nothing this Bloc could actually fetch/decode into a
                // LogoLayer for a brand kit's *saved* logo. A future
                // branch that resolves that gap (or adds a
                // logo-currently-in-session-only source, mirroring
                // BrandKitPage's own preview-only workaround) is where an
                // initial LogoLayer would get wired in.
              ),
            ),
            err: _toFailureState,
          ),
        );
      },
      err: (failure) async => emit(_toFailureState(failure)),
    );
  }

  /// `GenerationRepository`/`NetworkImageDecoder` both surface via the
  /// generic `Result<Failure, T>` base type; normalizing any non-`ApiFailure`
  /// into `ApiErrorType.unknown` here mirrors `GenerationBloc`'s identical
  /// normalization so an unanticipated `Failure` subtype (e.g.
  /// `DecodeGeneratedImageUseCase`'s `UnexpectedFailure`) degrades to
  /// generic "something went wrong" copy instead of a force-cast crash.
  ImageGenerationFailure _toFailureState(Failure failure) {
    return ImageGenerationFailure(
      failure is ApiFailure
          ? failure
          : ApiFailure(type: ApiErrorType.unknown, message: failure.message),
    );
  }
}
