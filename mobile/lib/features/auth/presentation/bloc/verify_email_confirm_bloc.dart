import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/features/auth/domain/usecases/verify_email_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/verify_email_confirm_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/verify_email_confirm_state.dart';

/// `droppable()` deliberately — submit-style action, same double-submit
/// protection as the rest of the auth flow (see
/// mobile/.claude/skills/flutter-state-management/SKILL.md).
@injectable
class VerifyEmailConfirmBloc
    extends Bloc<VerifyEmailConfirmEvent, VerifyEmailConfirmState> {
  VerifyEmailConfirmBloc(this._verifyEmailUseCase)
    : super(const VerifyEmailConfirmInitial()) {
    on<VerifyEmailConfirmSubmitted>(_onSubmitted, transformer: droppable());
  }

  final VerifyEmailUseCase _verifyEmailUseCase;

  Future<void> _onSubmitted(
    VerifyEmailConfirmSubmitted event,
    Emitter<VerifyEmailConfirmState> emit,
  ) async {
    emit(const VerifyEmailConfirmSubmitting());
    final result = await _verifyEmailUseCase(token: event.token);
    emit(
      result.when(
        // `verified: false` on an otherwise-successful call isn't
        // documented as a real backend outcome (POST /auth/verify-email's
        // 200 response means verified), but it's not modeled as
        // impossible either — treated as a failure defensively rather
        // than silently reporting success for something that isn't one.
        ok: (verified) => verified
            ? const VerifyEmailConfirmSuccess()
            : const VerifyEmailConfirmFailure(
                'This verification link is invalid or has expired.',
              ),
        err: (failure) => VerifyEmailConfirmFailure(failure.message),
      ),
    );
  }
}
