import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelal_studio/core/database/app_database.dart';
import 'package:kelal_studio/features/drafts/data/repositories/draft_repository_impl.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';

/// PRD-mandated critical flow (see
/// mobile/.claude/skills/flutter-testing/SKILL.md's Integration/E2E
/// section and this branch's own report): start a draft, force-kill/
/// reopen, assert it's intact.
///
/// **What this test can and can't simulate**: `flutter test
/// integration_test/` has no way to actually kill and relaunch the OS
/// process running this test — there's no scriptable equivalent of
/// swiping an app away and reopening it. What *is* real here: this uses
/// [AppDatabase]'s genuine constructor (`AppDatabase()`, not
/// `AppDatabase.forTesting(...)`'s in-memory one), which opens the same
/// real, file-backed `kelal_studio.sqlite` in the platform's actual
/// app-documents directory that a real app run would. Closing that
/// connection and opening a *second*, independent [AppDatabase] instance
/// against the same file is the closest thing to "the app process ended
/// and restarted" that's actually verifiable: SQLite's durability
/// guarantees are about the file on disk, not about which process or
/// connection wrote it, so if a draft saved through the first connection
/// is still readable through a completely separate second connection,
/// that's real evidence it would survive a genuine force-kill too — the
/// one thing this can't additionally prove is that the OS didn't corrupt
/// the file mid-write during an actual kill, which is SQLite's own
/// journaling contract, not this app's code, to guarantee.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const snapshot = DraftCanvasSnapshot(
    backgroundImagePath: '/tmp/draft-continuity-test.png',
    canvasWidth: 1080,
    canvasHeight: 1080,
    textLayers: [
      DraftTextLayerSnapshot(
        id: 'layer-1',
        text: 'Summer Sale — 50% Off',
        dx: 0.1,
        dy: 0.2,
        normalizedMaxWidth: 0.8,
        fontSize: 32,
        fontWeightIndex: 700,
        colorValue: 0xFFFFFFFF,
        textAlignIndex: 0,
      ),
    ],
  );

  testWidgets('a draft saved through one AppDatabase connection is still fully '
      'intact when read back through a completely independent second '
      'connection to the same on-disk database file', (tester) async {
    final draft = Draft(
      localId: 'continuity-test-${DateTime.now().microsecondsSinceEpoch}',
      brandKitId: 'brand-kit-1',
      inputText: 'Announce our summer sale with 50% off everything',
      generationRecordId: null,
      canvasSnapshot: snapshot,
      status: DraftStatus.draft,
      createdAt: DateTime.utc(2026),
      lastSavedAt: DateTime.utc(2026, 1, 1, 12, 30),
    );

    // "Session 1": the app is running, autosave writes this draft.
    final firstConnection = AppDatabase();
    final firstRepository = DraftRepositoryImpl(firstConnection);
    final saveResult = await firstRepository.save(draft);
    expect(saveResult.isOk, isTrue);
    // Closing (not just dropping the reference) is the point — a real
    // force-kill leaves nothing running, this leaves no open connection
    // either.
    await firstConnection.close();

    // "Session 2": the app is relaunched from scratch.
    final secondConnection = AppDatabase();
    addTearDown(secondConnection.close);
    final secondRepository = DraftRepositoryImpl(secondConnection);

    final draftsAfterRestart = await secondRepository.watchAll().first;
    final recovered = draftsAfterRestart.firstWhere(
      (d) => d.localId == draft.localId,
      orElse: () => fail(
        'draft ${draft.localId} was not found after reopening the '
        'database — this is the exact continuity failure PRD §10.5 '
        'requires this test to catch',
      ),
    );

    expect(recovered.inputText, draft.inputText);
    expect(recovered.brandKitId, draft.brandKitId);
    expect(recovered.status, draft.status);
    expect(recovered.lastSavedAt, draft.lastSavedAt);
    expect(recovered.canvasSnapshot.canvasWidth, snapshot.canvasWidth);
    expect(recovered.canvasSnapshot.canvasHeight, snapshot.canvasHeight);
    expect(recovered.canvasSnapshot.textLayers, hasLength(1));
    expect(
      recovered.canvasSnapshot.textLayers.single.text,
      'Summer Sale — 50% Off',
    );

    // Clean up: this test writes into the same real, shared
    // kelal_studio.sqlite a genuine app run on this device would use —
    // leaving the row behind would leak a fake draft into that real
    // database.
    await secondRepository.delete(draft.localId);
  });
}
