import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/usecases/register_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_state.dart';

/// `droppable()` deliberately, same reasoning as `LoginBloc`: a submit-style
/// action where a double-tap must not fire the request twice — see
/// mobile/.claude/skills/flutter-state-management/SKILL.md's transformer
/// selection table.
@injectable
class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  RegisterBloc(this._registerUseCase) : super(const RegisterInitial()) {
    on<RegisterSubmitted>(_onSubmitted, transformer: droppable());
  }

  final RegisterUseCase _registerUseCase;

  Future<void> _onSubmitted(
    RegisterSubmitted event,
    Emitter<RegisterState> emit,
  ) async {
    emit(const RegisterSubmitting());
    final result = await _registerUseCase(
      email: event.email,
      password: event.password,
    );
    emit(
      result.when(
        ok: (_) => RegisterSuccess(event.email),
        err: (failure) => RegisterFailure(
          failure.message,
          failure is ApiFailure ? failure.type : ApiErrorType.unknown,
        ),
      ),
    );
  }
}
