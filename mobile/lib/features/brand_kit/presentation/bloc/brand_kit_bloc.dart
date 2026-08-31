import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/update_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/upload_brand_logo_usecase.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_event.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_state.dart';
import 'package:uuid/uuid.dart';

/// Every handler here uses `droppable()`, deliberately — see
/// mobile/.claude/skills/flutter-state-management/SKILL.md's transformer
/// table ("Submit-style actions ... ignores new events while one's in
/// flight"). All three of this Bloc's events are single-shot, user-tap-
/// triggered actions (load-on-mount, tap-Save, tap-the-avatar-to-upload) —
/// none of them are a "live recompute" (`restartable()`) or an "ordered
/// local write sequence" (`sequential()`); each is closer to
/// `LoginBloc`/`RegisterBloc`/`DeleteAccountBloc`'s existing precedent than
/// to either of those. Concretely:
///  - [BrandKitSaveRequested]: a double-tap on the Save button must not
///    fire two overlapping `PUT /brand-kits/{id}` calls — the second one
///    could race the first and land its (possibly stale) response after
///    it, silently reverting a field the first save's response had
///    already applied. Dropping the second tap while one save is in flight
///    is the structural fix (same reasoning as `RegisterBloc`).
///  - [BrandKitLogoUploadRequested]: same reasoning for a double-tap on the
///    logo tile — two concurrent `/assets` uploads racing to overwrite
///    [BrandKitState]'s pending `logoAssetId` is exactly the kind of bug
///    this transformer exists to make structurally impossible.
///  - [BrandKitLoadRequested]: only ever dispatched once (page mount), but
///    kept `droppable()` rather than the implicit `concurrent()` default on
///    the same "don't leave a handler unreasoned-about" principle from
///    mobile/CLAUDE.md — if a future change adds pull-to-refresh, a
///    double-fire won't launch two concurrent GETs.
@injectable
class BrandKitBloc extends Bloc<BrandKitEvent, BrandKitState> {
  BrandKitBloc(
    this._getBrandKitUseCase,
    this._updateBrandKitUseCase,
    this._uploadBrandLogoUseCase,
  ) : super(const BrandKitInitial()) {
    on<BrandKitLoadRequested>(_onLoadRequested, transformer: droppable());
    on<BrandKitSaveRequested>(_onSaveRequested, transformer: droppable());
    on<BrandKitLogoUploadRequested>(
      _onLogoUploadRequested,
      transformer: droppable(),
    );
  }

  final GetBrandKitUseCase _getBrandKitUseCase;
  final UpdateBrandKitUseCase _updateBrandKitUseCase;
  final UploadBrandLogoUseCase _uploadBrandLogoUseCase;

  Future<void> _onLoadRequested(
    BrandKitLoadRequested event,
    Emitter<BrandKitState> emit,
  ) async {
    emit(const BrandKitLoadInProgress());
    final result = await _getBrandKitUseCase();
    emit(
      result.when(
        ok: BrandKitLoaded.new,
        err: (failure) {
          // A 404 here means "no kit yet, this account has never saved
          // one" — backend's `PUT /brand-kits/{id}` is a deliberate
          // owner-scoped upsert specifically for this case (see
          // `RealBrandKitRemoteDataSource`'s doc comment), so the correct
          // response is an empty, ready-to-fill-in form, not a dead-end
          // error screen. Every real first-time user hits this exact path
          // — it was previously indistinguishable from a genuine failure,
          // with a Retry button that would 404 forever.
          if (failure is ApiFailure && failure.type == ApiErrorType.notFound) {
            return BrandKitLoaded(_emptyDraft());
          }
          return BrandKitLoadFailure(failure.message);
        },
      ),
    );
  }

  /// A blank draft for the cold-start "no kit yet" case — see
  /// `_onLoadRequested`. [BrandKit.id] here is cosmetic: the real backend
  /// ignores the request body's `id` field entirely (the path segment,
  /// resolved by `RealBrandKitRemoteDataSource`, is what actually
  /// addresses the upsert) — this never reaches the fake data source at
  /// all, since it always resolves `getBrandKit()` against one seeded kit
  /// and never 404s.
  static BrandKit _emptyDraft() => BrandKit(
    id: const Uuid().v4(),
    brandName: '',
    logoAssetId: null,
    primaryColorHex: '',
    secondaryColorHex: '',
    toneOfVoice: '',
    contactInfo: '',
    updatedAt: DateTime.now().toUtc(),
  );

  Future<void> _onSaveRequested(
    BrandKitSaveRequested event,
    Emitter<BrandKitState> emit,
  ) async {
    emit(BrandKitSaving(event.brandKit));
    final result = await _updateBrandKitUseCase(event.brandKit);
    emit(
      result.when(
        ok: BrandKitLoaded.new,
        err: (failure) => BrandKitSaveFailure(event.brandKit, failure.message),
      ),
    );
  }

  Future<void> _onLogoUploadRequested(
    BrandKitLogoUploadRequested event,
    Emitter<BrandKitState> emit,
  ) async {
    final current = state;
    // The logo tile is only reachable once a draft exists, so this should
    // be unreachable in practice — guarded defensively rather than assumed.
    if (current is! BrandKitReady) return;
    final draft = current.brandKit;

    emit(BrandKitUploadingLogo(draft));
    final result = await _uploadBrandLogoUseCase(
      bytes: event.bytes,
      filename: event.filename,
      mimeType: event.mimeType,
    );
    emit(
      result.when(
        // Upload alone doesn't persist the association server-side (see
        // BrandKitRepository.uploadLogo's doc comment) — this only updates
        // the local draft; the user must still press Save.
        ok: (assetId) => BrandKitLoaded(draft.copyWith(logoAssetId: assetId)),
        err: (failure) => BrandKitLogoUploadFailure(draft, failure.message),
      ),
    );
  }
}
