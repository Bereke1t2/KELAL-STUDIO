import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md.
@injectable
class RequestPasswordResetUseCase {
  RequestPasswordResetUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<Failure, void>> call({required String email}) {
    return _repository.requestPasswordReset(email: email);
  }
}
