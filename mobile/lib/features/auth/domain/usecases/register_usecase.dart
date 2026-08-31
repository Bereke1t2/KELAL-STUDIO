import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/entities/registration_outcome.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Blocs call use
/// cases, never repositories directly.
@injectable
class RegisterUseCase {
  RegisterUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<Failure, RegistrationOutcome>> call({
    required String email,
    required String password,
  }) {
    return _repository.register(email: email, password: password);
  }
}
