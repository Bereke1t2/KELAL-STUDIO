import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_event.dart';
import 'package:kelal_studio/features/settings/presentation/bloc/account_state.dart';

@injectable
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc(this._deleteAccountUseCase) : super(const AccountInitial()) {
    on<AccountDeleteRequested>(
      _onAccountDeleteRequested,
      transformer: droppable(),
    );
  }

  final DeleteAccountUseCase _deleteAccountUseCase;

  Future<void> _onAccountDeleteRequested(
    AccountDeleteRequested event,
    Emitter<AccountState> emit,
  ) async {
    emit(const AccountDeleting());
    final result = await _deleteAccountUseCase();

    switch (result) {
      case Ok():
        emit(const AccountDeleted());
      case Err():
        emit(
          const AccountDeleteError(
            'Failed to delete account. Please try again.',
          ),
        );
    }
  }
}
