import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';

/// Interface only — no `drift` import here. `data/repositories
/// /draft_repository_impl.dart` is the only place that talks to
/// `core/database/app_database.dart` directly. See
/// mobile/.claude/skills/flutter-architecture/SKILL.md and
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
abstract class DraftsRepository {
  /// Drift's native reactive query, exposed as a bare `Stream` rather than
  /// `Result`-wrapped — deliberately, not an oversight. Every other method
  /// on this interface is a one-shot `Future` that can fail *at the moment
  /// it runs* (a single Drift statement, a single file write), which is
  /// exactly what `Result<Failure, T>` exists to represent. A reactive
  /// local query has no equivalent "did this attempt fail" moment once
  /// it's been constructed: `Stream.watch()` either successfully starts
  /// watching (this method returns) or the query itself was malformed at
  /// compile time (a bug this codebase's tests would already catch, not a
  /// runtime `Result.err` case), so there's nothing meaningful for an
  /// `Err` state on this stream to ever represent.
  Stream<List<Draft>> watchAll();

  /// Inserts a new draft or updates an existing one (matched on
  /// [Draft.localId]) — see `DraftRepositoryImpl.save`'s doc comment for
  /// the exact upsert + [Draft.maxLocalDrafts] eviction behavior.
  Future<Result<Failure, void>> save(Draft draft);

  Future<Result<Failure, void>> delete(String localId);
}
