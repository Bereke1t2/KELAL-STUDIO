import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';
import 'package:kelal_studio/features/auth/domain/usecases/login_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/login_state.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

void main() {
  late MockLoginUseCase loginUseCase;

  setUp(() {
    loginUseCase = MockLoginUseCase();
  });

  const email = 'demo@kelalstudio.app';
  const password = 'password123';

  blocTest<LoginBloc, LoginState>(
    'emits [LoginSubmitting, LoginSuccess] when login succeeds',
    setUp: () {
      when(() => loginUseCase(email: email, password: password)).thenAnswer(
        (_) async => const Result.ok(
          AuthSession(isAuthenticated: true, emailVerified: true),
        ),
      );
    },
    build: () => LoginBloc(loginUseCase),
    act: (bloc) =>
        bloc.add(const LoginSubmitted(email: email, password: password)),
    expect: () => const [LoginSubmitting(), LoginSuccess()],
  );

  blocTest<LoginBloc, LoginState>(
    'emits [LoginSubmitting, LoginFailure] with the failure message '
    'when login fails',
    setUp: () {
      when(() => loginUseCase(email: email, password: 'wrong')).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.validationError,
            message: 'Invalid email or password.',
          ),
        ),
      );
    },
    build: () => LoginBloc(loginUseCase),
    act: (bloc) =>
        bloc.add(const LoginSubmitted(email: email, password: 'wrong')),
    expect: () => const [
      LoginSubmitting(),
      LoginFailure('Invalid email or password.', ApiErrorType.validationError),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'droppable transformer: a second submit fired while the first is still '
    'in flight is ignored, not queued or run concurrently — this is the '
    'structural fix for a double-tap submitting the login form twice',
    setUp: () {
      when(() => loginUseCase(email: email, password: password)).thenAnswer((
        _,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result.ok(
          AuthSession(isAuthenticated: true, emailVerified: true),
        );
      });
    },
    build: () => LoginBloc(loginUseCase),
    act: (bloc) {
      bloc
        ..add(const LoginSubmitted(email: email, password: password))
        ..add(const LoginSubmitted(email: email, password: password));
    },
    wait: const Duration(milliseconds: 100),
    expect: () => const [LoginSubmitting(), LoginSuccess()],
    verify: (_) {
      // Exactly one login attempt reached the use case, not two.
      verify(() => loginUseCase(email: email, password: password)).called(1);
    },
  );
}
