import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/database/app_database.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/drafts/data/repositories/draft_repository_impl.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';

/// A minimal, valid [DraftCanvasSnapshot] fixture — never actually decoded
/// back into a `CanvasScene` in this file (that's
/// `draft_canvas_snapshot_test.dart`'s job, and the real
/// `DraftCanvasSnapshot.fromCanvasScene`/`toCanvasScene` round trip needs a
/// real `dart:ui` image + `path_provider`, neither of which this
/// repository-focused test needs to exercise). `DraftRepositoryImpl` only
/// ever treats a snapshot as an opaque `toJson()`/`fromJson()` payload.
DraftCanvasSnapshot _snapshot() {
  return const DraftCanvasSnapshot(
    backgroundImagePath: '/tmp/fake.png',
    canvasWidth: 1080,
    canvasHeight: 1080,
    textLayers: [],
  );
}

Draft _draft({
  required String localId,
  required DateTime lastSavedAt,
  String inputText = 'A test idea',
}) {
  return Draft(
    localId: localId,
    brandKitId: null,
    inputText: inputText,
    generationRecordId: null,
    canvasSnapshot: _snapshot(),
    status: DraftStatus.draft,
    createdAt: lastSavedAt,
    lastSavedAt: lastSavedAt,
  );
}

void main() {
  late AppDatabase db;
  late DraftRepositoryImpl repository;

  setUp(() {
    // In-memory SQLite via drift's own test-oriented NativeDatabase — real
    // SQL, no filesystem, no DI — exactly what AppDatabase.forTesting
    // exists for (see its own doc comment).
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DraftRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('save + watchAll', () {
    test(
      'a saved draft is readable back via watchAll, most-recent first',
      () async {
        final older = _draft(
          localId: 'draft-1',
          lastSavedAt: DateTime.utc(2026),
        );
        final newer = _draft(
          localId: 'draft-2',
          inputText: 'A newer idea',
          lastSavedAt: DateTime.utc(2026, 1, 2),
        );

        expect((await repository.save(older)).isOk, isTrue);
        expect((await repository.save(newer)).isOk, isTrue);

        final drafts = await repository.watchAll().first;
        expect(drafts.map((d) => d.localId), ['draft-2', 'draft-1']);
        expect(drafts.first.inputText, 'A newer idea');
      },
    );

    test('saving twice with the same localId updates the row instead of '
        'inserting a second one — DraftAutosaveCubit relies on this for '
        'repeated autosaves within one editing session', () async {
      final v1 = _draft(
        localId: 'draft-1',
        inputText: 'First draft of the idea',
        lastSavedAt: DateTime.utc(2026),
      );
      final v2 = v1.copyWith(
        inputText: 'Revised idea text',
        lastSavedAt: DateTime.utc(2026, 1, 1, 0, 0, 5),
      );

      await repository.save(v1);
      await repository.save(v2);

      final drafts = await repository.watchAll().first;
      expect(drafts, hasLength(1));
      expect(drafts.single.inputText, 'Revised idea text');
    });

    test(
      'saving past Draft.maxLocalDrafts evicts only the least-recently-saved '
      'draft',
      () async {
        for (var i = 0; i < Draft.maxLocalDrafts; i++) {
          await repository.save(
            _draft(
              localId: 'draft-$i',
              lastSavedAt: DateTime.utc(2026).add(Duration(minutes: i)),
            ),
          );
        }
        var drafts = await repository.watchAll().first;
        expect(drafts, hasLength(Draft.maxLocalDrafts));

        // draft-0 has the oldest lastSavedAt of the 20 already saved —
        // this insert should evict exactly that one.
        await repository.save(
          _draft(
            localId: 'draft-new',
            lastSavedAt: DateTime.utc(
              2026,
            ).add(const Duration(minutes: Draft.maxLocalDrafts)),
          ),
        );

        drafts = await repository.watchAll().first;
        expect(drafts, hasLength(Draft.maxLocalDrafts));
        expect(drafts.map((d) => d.localId), isNot(contains('draft-0')));
        expect(drafts.map((d) => d.localId), contains('draft-new'));
      },
    );
  });

  group('delete', () {
    test('removes the draft with the given localId', () async {
      await repository.save(
        _draft(localId: 'draft-1', lastSavedAt: DateTime.utc(2026)),
      );

      final result = await repository.delete('draft-1');

      expect(result.isOk, isTrue);
      expect(await repository.watchAll().first, isEmpty);
    });

    test(
      'deleting a localId that does not exist still succeeds (no-op)',
      () async {
        final result = await repository.delete('never-existed');
        expect(result.isOk, isTrue);
      },
    );
  });

  group('failure mapping', () {
    // Forces a genuine SQL-level failure (rather than relying on
    // db.close() — this drift/NativeDatabase version doesn't reliably
    // throw on a query issued after close(), it can silently reopen) so
    // these tests exercise a real exception hitting the try/catch, not a
    // no-op.
    test('save maps an unanticipated exception (e.g. a corrupted table) to '
        'CacheFailure rather than propagating it', () async {
      await db.customStatement('DROP TABLE drafts');

      final result = await repository.save(
        _draft(localId: 'draft-1', lastSavedAt: DateTime.utc(2026)),
      );

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected an error'),
        err: (failure) => expect(failure, isA<CacheFailure>()),
      );
    });

    test('delete maps an unanticipated exception to CacheFailure rather than '
        'propagating it', () async {
      await db.customStatement('DROP TABLE drafts');

      final result = await repository.delete('draft-1');

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected an error'),
        err: (failure) => expect(failure, isA<CacheFailure>()),
      );
    });
  });
}
