import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_bloc.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_event.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_state.dart';
import 'package:mocktail/mocktail.dart';

class MockDeleteAccountUseCase extends Mock implements DeleteAccountUseCase {}

void main() {
  late MockDeleteAccountUseCase deleteAccountUseCase;

  setUp(() {
    deleteAccountUseCase = MockDeleteAccountUseCase();
  });

  blocTest<AccountBloc, AccountState>(
    'emits [AccountDeleting, AccountDeleted] when deletion succeeds',
    setUp: () {
      when(
        () => deleteAccountUseCase(),
      ).thenAnswer((_) async => const Result.ok(null));
    },
    build: () => AccountBloc(deleteAccountUseCase),
    act: (bloc) => bloc.add(const AccountDeleteRequested()),
    expect: () => const [AccountDeleting(), AccountDeleted()],
  );

  blocTest<AccountBloc, AccountState>(
    'emits [AccountDeleting, AccountDeleteError] when deletion fails',
    setUp: () {
      when(() => deleteAccountUseCase()).thenAnswer(
        (_) async => const Result.err(
          ApiFailure(
            type: ApiErrorType.unknown,
            message: 'Internal server error',
          ),
        ),
      );
    },
    build: () => AccountBloc(deleteAccountUseCase),
    act: (bloc) => bloc.add(const AccountDeleteRequested()),
    expect: () => const [
      AccountDeleting(),
      AccountDeleteError('Failed to delete account. Please try again.'),
    ],
  );

  blocTest<AccountBloc, AccountState>(
    'droppable transformer: a second submit fired while the first is still '
    'in flight is ignored',
    setUp: () {
      when(() => deleteAccountUseCase()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const Result.ok(null);
      });
    },
    build: () => AccountBloc(deleteAccountUseCase),
    act: (bloc) {
      bloc
        ..add(const AccountDeleteRequested())
        ..add(const AccountDeleteRequested());
    },
    wait: const Duration(milliseconds: 100),
    expect: () => const [AccountDeleting(), AccountDeleted()],
    verify: (_) {
      verify(() => deleteAccountUseCase()).called(1);
    },
  );
}
