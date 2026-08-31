import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/features/quota/domain/usecases/get_quota_usecase.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_event.dart';
import 'package:kelal_studio/features/quota/presentation/bloc/quota_state.dart';

/// [QuotaRequested] uses `restartable()`, deliberately different from
/// `BrandKitBloc`'s `droppable()` choice for its load event — see
/// mobile/.claude/skills/flutter-state-management/SKILL.md's transformer
/// table.
///
/// `GET /quota/me` is a read-only, idempotent fetch, not a quota-consuming
/// or otherwise side-effecting action (unlike `BrandKitSaveRequested`'s
/// `PUT`) — there's no "double submit" hazard `droppable()` exists to
/// prevent, so reaching for it here would just be copying the *shape* of
/// `BrandKitBloc` without the reasoning that justified it there.
///
/// What *is* a real hazard: `QuotaRequested` fires on every
/// `QuotaStatusBadge` mount (i.e. every `/compose` page visit), so rapid
/// navigation in/out of Compose — or a future "refresh after a generation
/// call" trigger — can fire several `QuotaRequested` events in quick
/// succession, each racing the network. With `droppable()`, a *newer*
/// refresh (e.g. one fired right after a generation call that just
/// consumed quota) would be silently ignored if an earlier, now-stale
/// fetch happened to still be in flight — showing a stale badge exactly
/// when PRD §6.14 needs it to be current ("remaining quota visible
/// *before* a generation attempt"). `restartable()` cancels the stale
/// in-flight fetch and always resolves to the most recently requested one,
/// so the badge can never display a superseded reading — the same
/// "only the latest input matters" reasoning `flutter-state-management`
/// gives for live-recompute cases, applied here to a live-recompute-style
/// read rather than a canvas preview.
@injectable
class QuotaBloc extends Bloc<QuotaEvent, QuotaState> {
  QuotaBloc(this._getQuotaUseCase) : super(const QuotaInitial()) {
    on<QuotaRequested>(_onRequested, transformer: restartable());
  }

  final GetQuotaUseCase _getQuotaUseCase;

  Future<void> _onRequested(
    QuotaRequested event,
    Emitter<QuotaState> emit,
  ) async {
    emit(const QuotaLoadInProgress());
    final result = await _getQuotaUseCase();
    emit(
      result.when(
        ok: QuotaLoaded.new,
        err: (failure) => QuotaLoadFailure(failure.message),
      ),
    );
  }
}
