import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';
import 'package:kelal_studio/features/quota/domain/repositories/quota_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Blocs call use
/// cases, never repositories directly.
@injectable
class GetQuotaUseCase {
  GetQuotaUseCase(this._repository);

  final QuotaRepository _repository;

  Future<Result<Failure, Quota>> call() => _repository.getQuota();
}
