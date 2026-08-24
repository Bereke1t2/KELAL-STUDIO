import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_bloc.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_event.dart';
import 'package:kelal_studio/features/auth/presentation/bloc/reset_password_request_state.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestPasswordResetUseCase extends Mock
    implements RequestPasswordResetUseCase {}

void main() {
  late MockRequestPasswordResetUseCase useCase;

  setUp(() {
    useCase = MockRequestPasswordResetUseCase();
  });

  const existingEmail = 'demo@kelalstudio.app';
  const unknownEmail = 'nobody@kelalstudio.app';

  blocTest<ResetPasswordRequestBloc, ResetPasswordRequestState>(
    'an existing email reaches ResetPasswordRequestSuccess',
    setUp: () {
      when(
        () => useCase(email: existingEmail),
      ).thenAnswer((_) async => const Result.ok(null));
    },
    build: () => ResetPasswordRequestBloc(useCase),
    act: (bloc) =>
        bloc.add(const ResetPasswordRequestSubmitted(email: existingEmail)),
    expect: () => const [
      ResetPasswordRequestSubmitting(),
      ResetPasswordRequestSuccess(),
    ],
  );

  blocTest<ResetPasswordRequestBloc, ResetPasswordRequestState>(
    'a nonexistent email reaches the exact same ResetPasswordRequestSuccess '
    'state as an existing one — the anti-enumeration contract (PRD §6.1) '
    'means there is no distinguishable failure state for this',
    setUp: () {
      when(
        () => useCase(email: unknownEmail),
      ).thenAnswer((_) async => const Result.ok(null));
    },
    build: () => ResetPasswordRequestBloc(useCase),
    act: (bloc) =>
        bloc.add(const ResetPasswordRequestSubmitted(email: unknownEmail)),
    expect: () => const [
      ResetPasswordRequestSubmitting(),
      ResetPasswordRequestSuccess(),
    ],
  );

  blocTest<ResetPasswordRequestBloc, ResetPasswordRequestState>(
    'a genuine transport failure reaches ResetPasswordRequestFailure',
    setUp: () {
      when(() => useCase(email: existingEmail)).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.network,
            message: 'No connection. Check your network and try again.',
          ),
        ),
      );
    },
    build: () => ResetPasswordRequestBloc(useCase),
    act: (bloc) =>
        bloc.add(const ResetPasswordRequestSubmitted(email: existingEmail)),
    expect: () => const [
      ResetPasswordRequestSubmitting(),
      ResetPasswordRequestFailure(
        'No connection. Check your network and try again.',
      ),
    ],
  );

  blocTest<ResetPasswordRequestBloc, ResetPasswordRequestState>(
    'droppable transformer: a second submit fired while the first is still '
    'in flight is ignored',
    setUp: () {
      when(() => useCase(email: existingEmail)).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result.ok(null);
      });
    },
    build: () => ResetPasswordRequestBloc(useCase),
    act: (bloc) {
      bloc
        ..add(const ResetPasswordRequestSubmitted(email: existingEmail))
        ..add(const ResetPasswordRequestSubmitted(email: existingEmail));
    },
    wait: const Duration(milliseconds: 100),
    expect: () => const [
      ResetPasswordRequestSubmitting(),
      ResetPasswordRequestSuccess(),
    ],
    verify: (_) {
      verify(() => useCase(email: existingEmail)).called(1);
    },
  );
}
