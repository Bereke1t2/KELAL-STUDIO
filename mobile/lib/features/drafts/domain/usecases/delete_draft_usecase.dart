import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/drafts/domain/repositories/draft_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md.
@injectable
class DeleteDraftUseCase {
  DeleteDraftUseCase(this._repository);

  final DraftsRepository _repository;

  Future<Result<Failure, void>> call(String localId) =>
      _repository.delete(localId);
}
