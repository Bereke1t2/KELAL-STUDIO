import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/features/auth/domain/usecases/resend_verification_email_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/resend_verification_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/resend_verification_state.dart';

/// `droppable()` deliberately — submit-style action, same double-tap
/// protection as `ResetPasswordRequestBloc`/`RegisterBloc` (see
/// mobile/.claude/skills/flutter-state-management/SKILL.md).
@injectable
class ResendVerificationBloc
    extends Bloc<ResendVerificationEvent, ResendVerificationState> {
  ResendVerificationBloc(this._resendVerificationEmailUseCase)
    : super(const ResendVerificationIdle()) {
    on<ResendVerificationRequested>(_onRequested, transformer: droppable());
  }

  final ResendVerificationEmailUseCase _resendVerificationEmailUseCase;

  Future<void> _onRequested(
    ResendVerificationRequested event,
    Emitter<ResendVerificationState> emit,
  ) async {
    emit(const ResendVerificationSending());
    final result = await _resendVerificationEmailUseCase(email: event.email);
    emit(
      result.when(
        // Always the same success state regardless of what the failure
        // *would* have been for a nonexistent/already-verified email —
        // same reasoning as ResetPasswordRequestBloc.
        ok: (_) => const ResendVerificationSent(),
        err: (failure) => ResendVerificationFailure(failure.message),
      ),
    );
  }
}
