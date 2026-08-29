import 'dart:async';
import 'dart:ui' as ui;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/delete_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/resume_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/watch_drafts_usecase.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_bloc.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_event.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_state.dart';
import 'package:mocktail/mocktail.dart';

class MockWatchDraftsUseCase extends Mock implements WatchDraftsUseCase {}

class MockDeleteDraftUseCase extends Mock implements DeleteDraftUseCase {}

class MockResumeDraftUseCase extends Mock implements ResumeDraftUseCase {}

class FakeDraft extends Fake implements Draft {}

Future<ui.Image> _testImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 4, 4),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4, 4);
  picture.dispose();
  return image;
}

void main() {
  late MockWatchDraftsUseCase watchDraftsUseCase;
  late MockDeleteDraftUseCase deleteDraftUseCase;
  late MockResumeDraftUseCase resumeDraftUseCase;
  late StreamController<List<Draft>> draftsController;
  late ui.Image background;

  const snapshot = DraftCanvasSnapshot(
    backgroundImagePath: '/tmp/fake.png',
    canvasWidth: 1080,
    canvasHeight: 1080,
    textLayers: [],
  );

  Draft draft(String id, {String inputText = 'An idea'}) => Draft(
    localId: id,
    brandKitId: null,
    inputText: inputText,
    generationRecordId: null,
    canvasSnapshot: snapshot,
    status: DraftStatus.draft,
    createdAt: DateTime.utc(2026),
    lastSavedAt: DateTime.utc(2026),
  );

  setUpAll(() {
    registerFallbackValue(FakeDraft());
  });

  setUp(() async {
    watchDraftsUseCase = MockWatchDraftsUseCase();
    deleteDraftUseCase = MockDeleteDraftUseCase();
    resumeDraftUseCase = MockResumeDraftUseCase();
    draftsController = StreamController<List<Draft>>.broadcast();
    background = await _testImage();
    when(() => watchDraftsUseCase()).thenAnswer((_) => draftsController.stream);
  });

  tearDown(() async {
    await draftsController.close();
  });

  DraftsListBloc buildBloc() => DraftsListBloc(
    watchDraftsUseCase,
    deleteDraftUseCase,
    resumeDraftUseCase,
  );

  group('DraftsListUpdated (via WatchDraftsUseCase subscription)', () {
    blocTest<DraftsListBloc, DraftsListState>(
      'starts in DraftsListLoading, then emits DraftsListLoaded once the '
      'underlying stream emits',
      build: buildBloc,
      act: (bloc) => draftsController.add([draft('d1')]),
      expect: () => [
        DraftsListLoaded([draft('d1')]),
      ],
    );

    blocTest<DraftsListBloc, DraftsListState>(
      'a later stream emission replaces the list entirely',
      build: buildBloc,
      act: (bloc) async {
        draftsController.add([draft('d1')]);
        await Future<void>.delayed(Duration.zero);
        draftsController.add([draft('d1'), draft('d2')]);
      },
      expect: () => [
        DraftsListLoaded([draft('d1')]),
        DraftsListLoaded([draft('d1'), draft('d2')]),
      ],
    );
  });

  group('DraftDeleteRequested', () {
    blocTest<DraftsListBloc, DraftsListState>(
      'calls DeleteDraftUseCase with the tapped localId',
      setUp: () {
        when(
          () => deleteDraftUseCase(any()),
        ).thenAnswer((_) async => const Result.ok(null));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const DraftDeleteRequested('d1')),
      verify: (_) {
        verify(() => deleteDraftUseCase('d1')).called(1);
      },
    );

    blocTest<DraftsListBloc, DraftsListState>(
      'a failed delete does not crash or emit an error state — the row '
      'simply stays in the next watchAll() emission',
      setUp: () {
        when(
          () => deleteDraftUseCase(any()),
        ).thenAnswer((_) async => const Result.err(CacheFailure('boom')));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const DraftDeleteRequested('d1')),
      expect: () => <DraftsListState>[],
    );
  });

  group('DraftResumeRequested', () {
    blocTest<DraftsListBloc, DraftsListState>(
      'resolves ResumeDraftUseCase for the tapped draft and emits it as '
      'resumedScene/resumedDraft alongside the current list',
      setUp: () {
        when(() => resumeDraftUseCase(any())).thenAnswer(
          (_) async => CanvasScene(
            backgroundImage: background,
            canvasSize: const Size(8, 8),
          ),
        );
      },
      build: buildBloc,
      seed: () => DraftsListLoaded([draft('d1'), draft('d2')]),
      act: (bloc) => bloc.add(const DraftResumeRequested('d2')),
      expect: () => [
        isA<DraftsListLoaded>()
            .having(
              (s) => s.resumedDraft?.localId,
              'resumedDraft.localId',
              'd2',
            )
            .having((s) => s.resumedScene, 'resumedScene', isNotNull),
      ],
      verify: (_) {
        verify(() => resumeDraftUseCase(draft('d2'))).called(1);
      },
    );

    blocTest<DraftsListBloc, DraftsListState>(
      'requesting a localId not present in the current list is a no-op',
      build: buildBloc,
      seed: () => DraftsListLoaded([draft('d1')]),
      act: (bloc) => bloc.add(const DraftResumeRequested('never-existed')),
      expect: () => <DraftsListState>[],
      verify: (_) {
        verifyNever(() => resumeDraftUseCase(any()));
      },
    );

    blocTest<DraftsListBloc, DraftsListState>(
      'requesting a resume while still DraftsListLoading is a no-op — '
      'there is no list to resolve the localId against yet',
      build: buildBloc,
      act: (bloc) => bloc.add(const DraftResumeRequested('d1')),
      expect: () => <DraftsListState>[],
      verify: (_) {
        verifyNever(() => resumeDraftUseCase(any()));
      },
    );

    blocTest<DraftsListBloc, DraftsListState>(
      'droppable transformer: a second resume request while the first is '
      'still in flight is ignored',
      setUp: () {
        when(() => resumeDraftUseCase(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return CanvasScene(
            backgroundImage: background,
            canvasSize: const Size(8, 8),
          );
        });
      },
      build: buildBloc,
      seed: () => DraftsListLoaded([draft('d1'), draft('d2')]),
      act: (bloc) => bloc
        ..add(const DraftResumeRequested('d1'))
        ..add(const DraftResumeRequested('d2')),
      wait: const Duration(milliseconds: 100),
      expect: () => [
        isA<DraftsListLoaded>().having(
          (s) => s.resumedDraft?.localId,
          'resumedDraft.localId',
          'd1',
        ),
      ],
      verify: (_) {
        verify(() => resumeDraftUseCase(any())).called(1);
      },
    );
  });
}
