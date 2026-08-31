import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/auth/domain/repositories/auth_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md.
///
/// **Not wired to a deep link yet — a real, flagged scope boundary, not a
/// silent gap.** The verification token this consumes only ever arrives
/// via a link in the account's verification email; actually consuming
/// that link needs platform-level Android App Links / iOS Universal Links
/// wiring (domain verification files this repo has no real domain to
/// serve yet), which is out of scope for this branch. This use case
/// exists so that plumbing is a routing change, not a new feature, once
/// deep links are wired — see `CheckYourEmailPage`'s doc comment for the
/// same note from the UI side.
@injectable
class VerifyEmailUseCase {
  VerifyEmailUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<Failure, bool>> call({required String token}) =>
      _repository.verifyEmail(token: token);
}
