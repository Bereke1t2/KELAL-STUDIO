import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/features/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_state.dart';

/// `droppable()` deliberately — submit-style action, same double-submit
/// protection as `LoginBloc`/`RegisterBloc` (see
/// mobile/.claude/skills/flutter-state-management/SKILL.md).
@injectable
class ResetPasswordRequestBloc
    extends Bloc<ResetPasswordRequestEvent, ResetPasswordRequestState> {
  ResetPasswordRequestBloc(this._requestPasswordResetUseCase)
    : super(const ResetPasswordRequestInitial()) {
    on<ResetPasswordRequestSubmitted>(_onSubmitted, transformer: droppable());
  }

  final RequestPasswordResetUseCase _requestPasswordResetUseCase;

  Future<void> _onSubmitted(
    ResetPasswordRequestSubmitted event,
    Emitter<ResetPasswordRequestState> emit,
  ) async {
    emit(const ResetPasswordRequestSubmitting());
    final result = await _requestPasswordResetUseCase(email: event.email);
    emit(
      result.when(
        // Always the same success state regardless of what the failure
        // *would* have been for a nonexistent email — the use case/
        // repository never returns an "email not found" branch to begin
        // with, so there is nothing to accidentally leak here.
        ok: (_) => const ResetPasswordRequestSuccess(),
        err: (failure) => ResetPasswordRequestFailure(failure.message),
      ),
    );
  }
}
