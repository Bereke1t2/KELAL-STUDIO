import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/entities/auth_session.dart';
import 'package:kelal_studio/features/auth/domain/usecases/register_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/register_state.dart';
import 'package:mocktail/mocktail.dart';

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

void main() {
  late MockRegisterUseCase registerUseCase;

  setUp(() {
    registerUseCase = MockRegisterUseCase();
  });

  const email = 'new@kelalstudio.app';
  const password = 'password123';

  blocTest<RegisterBloc, RegisterState>(
    'emits [RegisterSubmitting, RegisterSuccess] when registration '
    'succeeds',
    setUp: () {
      when(() => registerUseCase(email: email, password: password)).thenAnswer(
        (_) async => const Result.ok(
          AuthSession(isAuthenticated: true, emailVerified: false),
        ),
      );
    },
    build: () => RegisterBloc(registerUseCase),
    act: (bloc) =>
        bloc.add(const RegisterSubmitted(email: email, password: password)),
    expect: () => const [RegisterSubmitting(), RegisterSuccess()],
  );

  blocTest<RegisterBloc, RegisterState>(
    'emits [RegisterSubmitting, RegisterFailure] with the failure message '
    'when the email is already registered',
    setUp: () {
      when(() => registerUseCase(email: email, password: password)).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.validationError,
            message: 'An account with this email already exists.',
          ),
        ),
      );
    },
    build: () => RegisterBloc(registerUseCase),
    act: (bloc) =>
        bloc.add(const RegisterSubmitted(email: email, password: password)),
    expect: () => const [
      RegisterSubmitting(),
      RegisterFailure(
        'An account with this email already exists.',
        ApiErrorType.validationError,
      ),
    ],
  );

  blocTest<RegisterBloc, RegisterState>(
    'droppable transformer: a second submit fired while the first is still '
    'in flight is ignored, not queued or run concurrently',
    setUp: () {
      when(() => registerUseCase(email: email, password: password)).thenAnswer((
        _,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result.ok(
          AuthSession(isAuthenticated: true, emailVerified: false),
        );
      });
    },
    build: () => RegisterBloc(registerUseCase),
    act: (bloc) {
      bloc
        ..add(const RegisterSubmitted(email: email, password: password))
        ..add(const RegisterSubmitted(email: email, password: password));
    },
    wait: const Duration(milliseconds: 100),
    expect: () => const [RegisterSubmitting(), RegisterSuccess()],
    verify: (_) {
      verify(() => registerUseCase(email: email, password: password)).called(1);
    },
  );
}
