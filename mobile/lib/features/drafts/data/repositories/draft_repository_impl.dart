import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/database/app_database.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';
import 'package:kelal_studio/features/drafts/domain/repositories/draft_repository.dart';

@LazySingleton(as: DraftsRepository)
class DraftRepositoryImpl implements DraftsRepository {
  DraftRepositoryImpl(this._db);

  final AppDatabase _db;

  Draft _toDomain(DraftRow row) {
    return Draft(
      localId: row.localId,
      brandKitId: row.brandKitId,
      inputText: row.inputText,
      generationRecordId: row.generationRecordId,
      canvasSnapshot: DraftCanvasSnapshot.fromJson(
        jsonDecode(row.canvasStateJson) as Map<String, dynamic>,
      ),
      status: DraftStatus.fromWire(row.status),
      createdAt: row.createdAt,
      lastSavedAt: row.lastSavedAt,
    );
  }

  DraftsCompanion _toCompanion(Draft draft) {
    return DraftsCompanion.insert(
      localId: draft.localId,
      brandKitId: Value(draft.brandKitId),
      inputText: draft.inputText,
      generationRecordId: Value(draft.generationRecordId),
      canvasStateJson: jsonEncode(draft.canvasSnapshot.toJson()),
      status: draft.status.toWire(),
      createdAt: draft.createdAt,
      lastSavedAt: draft.lastSavedAt,
    );
  }

  @override
  Stream<List<Draft>> watchAll() {
    // Most-recently-saved first — the natural "pick up where you left off"
    // order for a drafts list, and also the order eviction below reads
    // from the opposite end of.
    final query = _db.select(_db.drafts)
      ..orderBy([(t) => OrderingTerm.desc(t.lastSavedAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Result<Failure, void>> save(Draft draft) async {
    try {
      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.drafts,
        )..where((t) => t.localId.equals(draft.localId))).getSingleOrNull();

        // Cap + eviction: only relevant for a genuinely *new* row — an
        // update to an existing draft never changes the row count, so it
        // never needs to evict anything (see `Draft.maxLocalDrafts`'s doc
        // comment for why 20 is a flagged default, not a real product
        // number).
        if (existing == null) {
          // A plain `.get().length` rather than a SQL `COUNT(*)` — this
          // table is capped at `Draft.maxLocalDrafts` (20) rows by this
          // very check, so fetching every row to count them is never a
          // real performance concern here.
          final currentCount = (await _db.select(_db.drafts).get()).length;

          if (currentCount >= Draft.maxLocalDrafts) {
            final oldest =
                await (_db.select(_db.drafts)
                      ..orderBy([(t) => OrderingTerm.asc(t.lastSavedAt)])
                      ..limit(1))
                    .getSingleOrNull();
            if (oldest != null) {
              await (_db.delete(
                _db.drafts,
              )..where((t) => t.localId.equals(oldest.localId))).go();
            }
          }
        }

        await _db.into(_db.drafts).insertOnConflictUpdate(_toCompanion(draft));
      });
      return const Result.ok(null);
    }
    // Deliberate catch-all: this is the repository boundary — per
    // flutter-architecture, nothing above this layer may throw, so any
    // exception type we didn't anticipate (e.g. the device is out of
    // storage and SQLite's write fails) still needs to become a
    // Result.err rather than propagate. Mirrors the exact pattern used
    // throughout `auth_repository_impl.dart`/`brand_kit_repository_impl.dart`.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        CacheFailure(
          "Couldn't save your draft — your device may be low on storage.",
        ),
      );
    }
  }

  @override
  Future<Result<Failure, void>> delete(String localId) async {
    try {
      await (_db.delete(
        _db.drafts,
      )..where((t) => t.localId.equals(localId))).go();
      return const Result.ok(null);
    }
    // Deliberate catch-all: repository boundary, same reasoning as save()
    // above — any unanticipated exception still becomes a Result.err.
    // ignore: avoid_catches_without_on_clauses
    catch (_) {
      return const Result.err(
        CacheFailure("Couldn't delete your draft — please try again."),
      );
    }
  }
}
