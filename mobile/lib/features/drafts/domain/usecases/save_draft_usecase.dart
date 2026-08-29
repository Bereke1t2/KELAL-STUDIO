import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/repositories/draft_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Blocs call use
/// cases, never repositories directly — in particular `DraftAutosaveCubit`
/// calls this, never `DraftsRepository`.
@injectable
class SaveDraftUseCase {
  SaveDraftUseCase(this._repository);

  final DraftsRepository _repository;

  Future<Result<Failure, void>> call(Draft draft) => _repository.save(draft);
}
