import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/features/auth/domain/usecases/confirm_password_reset_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_state.dart';

/// `droppable()` deliberately — submit-style action, same double-submit
/// protection as the rest of the auth flow (see
/// mobile/.claude/skills/flutter-state-management/SKILL.md).
@injectable
class ResetPasswordConfirmBloc
    extends Bloc<ResetPasswordConfirmEvent, ResetPasswordConfirmState> {
  ResetPasswordConfirmBloc(this._confirmPasswordResetUseCase)
    : super(const ResetPasswordConfirmInitial()) {
    on<ResetPasswordConfirmSubmitted>(_onSubmitted, transformer: droppable());
  }

  final ConfirmPasswordResetUseCase _confirmPasswordResetUseCase;

  Future<void> _onSubmitted(
    ResetPasswordConfirmSubmitted event,
    Emitter<ResetPasswordConfirmState> emit,
  ) async {
    emit(const ResetPasswordConfirmSubmitting());
    final result = await _confirmPasswordResetUseCase(
      token: event.token,
      newPassword: event.newPassword,
    );
    emit(
      result.when(
        ok: (_) => const ResetPasswordConfirmSuccess(),
        err: (failure) => ResetPasswordConfirmFailure(failure.message),
      ),
    );
  }
}
