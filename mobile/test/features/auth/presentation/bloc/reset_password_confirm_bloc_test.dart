import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/usecases/confirm_password_reset_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_confirm_state.dart';
import 'package:mocktail/mocktail.dart';

class MockConfirmPasswordResetUseCase extends Mock
    implements ConfirmPasswordResetUseCase {}

void main() {
  late MockConfirmPasswordResetUseCase useCase;

  setUp(() {
    useCase = MockConfirmPasswordResetUseCase();
  });

  const token = 'fake-reset-token';
  const newPassword = 'newpassword123';

  blocTest<ResetPasswordConfirmBloc, ResetPasswordConfirmState>(
    'emits [Submitting, Success] for a valid token',
    setUp: () {
      when(
        () => useCase(token: token, newPassword: newPassword),
      ).thenAnswer((_) async => const Result.ok(null));
    },
    build: () => ResetPasswordConfirmBloc(useCase),
    act: (bloc) => bloc.add(
      const ResetPasswordConfirmSubmitted(
        token: token,
        newPassword: newPassword,
      ),
    ),
    expect: () => const [
      ResetPasswordConfirmSubmitting(),
      ResetPasswordConfirmSuccess(),
    ],
  );

  blocTest<ResetPasswordConfirmBloc, ResetPasswordConfirmState>(
    'emits [Submitting, Failure] for an invalid/expired token',
    setUp: () {
      when(() => useCase(token: token, newPassword: newPassword)).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.validationError,
            message: 'This reset code is invalid or has expired.',
          ),
        ),
      );
    },
    build: () => ResetPasswordConfirmBloc(useCase),
    act: (bloc) => bloc.add(
      const ResetPasswordConfirmSubmitted(
        token: token,
        newPassword: newPassword,
      ),
    ),
    expect: () => const [
      ResetPasswordConfirmSubmitting(),
      ResetPasswordConfirmFailure('This reset code is invalid or has expired.'),
    ],
  );

  blocTest<ResetPasswordConfirmBloc, ResetPasswordConfirmState>(
    'droppable transformer: a second submit fired while the first is still '
    'in flight is ignored',
    setUp: () {
      when(() => useCase(token: token, newPassword: newPassword)).thenAnswer((
        _,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result.ok(null);
      });
    },
    build: () => ResetPasswordConfirmBloc(useCase),
    act: (bloc) {
      bloc
        ..add(
          const ResetPasswordConfirmSubmitted(
            token: token,
            newPassword: newPassword,
          ),
        )
        ..add(
          const ResetPasswordConfirmSubmitted(
            token: token,
            newPassword: newPassword,
          ),
        );
    },
    wait: const Duration(milliseconds: 100),
    expect: () => const [
      ResetPasswordConfirmSubmitting(),
      ResetPasswordConfirmSuccess(),
    ],
    verify: (_) {
      verify(() => useCase(token: token, newPassword: newPassword)).called(1);
    },
  );
}
