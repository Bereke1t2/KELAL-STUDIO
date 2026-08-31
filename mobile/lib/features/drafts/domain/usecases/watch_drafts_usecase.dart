import 'package:injectable/injectable.dart';

import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/repositories/draft_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Blocs call use
/// cases, never repositories directly.
///
/// Returns a bare `Stream`, not `Result`-wrapped — see
/// `DraftsRepository.watchAll`'s doc comment for why; this use case adds
/// no error-mapping of its own for the same reason.
@injectable
class WatchDraftsUseCase {
  WatchDraftsUseCase(this._repository);

  final DraftsRepository _repository;

  Stream<List<Draft>> call() => _repository.watchAll();
}
