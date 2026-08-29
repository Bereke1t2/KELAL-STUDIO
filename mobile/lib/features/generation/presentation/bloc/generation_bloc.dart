import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/generation/domain/usecases/generate_text_usecase.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_event.dart';
import 'package:kelal_studio/features/generation/presentation/bloc/generation_state.dart';

/// [GenerationRequested] uses `droppable()`, deliberately re-derived for
/// this Bloc rather than copied wholesale from either `QuotaBloc` or
/// `BrandKitBloc` — see
/// mobile/.claude/skills/flutter-state-management/SKILL.md's transformer
/// table.
///
/// `POST /generate/text` is not `QuotaBloc`'s read-only, idempotent GET —
/// `restartable()` would be wrong here for the same reason it's wrong for
/// `BrandKitSaveRequested`: this call has a side effect, not just a value
/// to refresh, so silently cancelling an in-flight one and starting a new
/// one is not safe. It's closest to `BrandKitBloc`'s `droppable()`
/// reasoning for `BrandKitSaveRequested`, but the stakes are higher here:
/// `/generate/text` consumes a scarce, per-user quota unit (PRD §6.14
/// treats quota as a financial control, not a UX nicety) on *every call
/// that reaches the backend*, not just on eventual success. A double-tap
/// on Generate that fired two overlapping requests wouldn't just risk
/// showing a stale caption (the `BrandKitSaveRequested` failure mode) — it
/// would silently burn two quota units for one user action, and if the
/// two calls raced, whichever response happened to land second is what
/// the user would see, with no guarantee it corresponds to their most
/// recent tap. `droppable()` is the structural fix: while one generate
/// call is in flight, further `GenerationRequested` events are ignored
/// outright (not queued) — the user must wait for the current one to
/// resolve, then press Generate again if they want another attempt.
/// `PrimaryButton.isLoading` disabling the button is a UX nicety on top of
/// this, not a substitute for it — the transformer is what actually
/// prevents a race if two events reach the Bloc regardless of button
/// state (e.g. a queued tap that lands just as `isLoading` flips).
@injectable
class GenerationBloc extends Bloc<GenerationEvent, GenerationState> {
  GenerationBloc(this._generateTextUseCase, this._getBrandKitUseCase)
    : super(const GenerationInitial()) {
    on<GenerationRequested>(_onRequested, transformer: droppable());
  }

  final GenerateTextUseCase _generateTextUseCase;
  final GetBrandKitUseCase _getBrandKitUseCase;

  Future<void> _onRequested(
    GenerationRequested event,
    Emitter<GenerationState> emit,
  ) async {
    emit(const GenerationInProgress());

    // `brand_kit_id` is optional on `GenerateTextRequest` (see
    // mobile/api_contract/openapi.yaml) — resolved here from whatever
    // brand kit is currently on file for this account, per this branch's
    // "wire from context, don't hardcode or invent" instruction. A
    // failure resolving it (no brand kit configured yet, or — against a
    // real backend — `RealBrandKitRemoteDataSource`'s own already-flagged
    // nil-UUID-placeholder gap, see that class's doc comment) is not
    // fatal to generation itself: the field is optional, so this falls
    // back to omitting it rather than blocking the whole generate call on
    // an unrelated feature's failure.
    final brandKitResult = await _getBrandKitUseCase();
    final brandKitId = brandKitResult.valueOrNull?.id;

    final result = await _generateTextUseCase(
      inputText: event.inputText,
      inputLanguage: event.inputLanguage,
      platform: event.platform,
      brandKitId: brandKitId,
    );
    emit(
      result.when(
        ok: GenerationSuccess.new,
        // GenerationRepository returns Result<Failure, GenerationResult>
        // (the same generic base every repository uses), but
        // GenerationFailure needs the richer ApiFailure specifically (see
        // its own doc comment) to drive showQuotaExceededDialog/the
        // per-ApiErrorType message mapping. In practice
        // GenerationRepositoryImpl only ever produces an ApiFailure or,
        // on its own catch-all, an UnexpectedFailure — the latter is
        // normalized into an ApiFailure(type: unknown) here rather than
        // force-casting, so an unanticipated Failure subtype degrades to
        // the generic "something went wrong" copy instead of crashing.
        err: (failure) => GenerationFailure(
          failure is ApiFailure
              ? failure
              : ApiFailure(
                  type: ApiErrorType.unknown,
                  message: failure.message,
                ),
        ),
      ),
    );
  }
}
