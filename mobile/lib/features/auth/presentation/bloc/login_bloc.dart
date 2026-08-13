import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/usecases/login_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_state.dart';

/// `droppable()` deliberately: while a login request is in flight, further
/// `LoginSubmitted` events (e.g. from an impatient double-tap on the submit
/// button) are ignored rather than queued or run concurrently — see
/// mobile/.claude/skills/flutter-state-management/SKILL.md's transformer
/// selection table. This is the direct, structural fix for the classic
/// "double-tap submits twice" race, not a debounce hack in the widget.
@injectable
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._loginUseCase) : super(const LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted, transformer: droppable());
  }

  final LoginUseCase _loginUseCase;

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginSubmitting());
    final result = await _loginUseCase(
      email: event.email,
      password: event.password,
    );
    emit(
      result.when(
        ok: (_) => const LoginSuccess(),
        err: (failure) => LoginFailure(
          failure.message,
          failure is ApiFailure ? failure.type : ApiErrorType.unknown,
        ),
      ),
    );
  }
}
