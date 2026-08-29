import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/delete_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/resume_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/watch_drafts_usecase.dart';
import 'package:kelal_studio/features/drafts/presentation/bloc/drafts_list_bloc.dart';
import 'package:kelal_studio/features/drafts/presentation/cubit/drafts_disclosure_seen_cubit.dart';
import 'package:kelal_studio/features/drafts/presentation/pages/drafts_page.dart';
import 'package:mocktail/mocktail.dart';

class MockWatchDraftsUseCase extends Mock implements WatchDraftsUseCase {}

class MockDeleteDraftUseCase extends Mock implements DeleteDraftUseCase {}

class MockResumeDraftUseCase extends Mock implements ResumeDraftUseCase {}

/// Same in-memory `Storage` seam as `export_overlay_seen_cubit_test.dart` —
/// `DraftsDisclosureSeenCubit` is a `HydratedCubit` too.
class _InMemoryStorage implements Storage {
  final _data = <String, dynamic>{};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> close() async {}
}

void main() {
  late MockWatchDraftsUseCase watchDraftsUseCase;
  late MockDeleteDraftUseCase deleteDraftUseCase;
  late MockResumeDraftUseCase resumeDraftUseCase;
  late StreamController<List<Draft>> draftsController;

  const snapshot = DraftCanvasSnapshot(
    backgroundImagePath: '/tmp/fake.png',
    canvasWidth: 1080,
    canvasHeight: 1080,
    textLayers: [],
  );

  Draft draft(String id, {required String inputText, DateTime? lastSavedAt}) {
    final saved = lastSavedAt ?? DateTime.now().toUtc();
    return Draft(
      localId: id,
      brandKitId: null,
      inputText: inputText,
      generationRecordId: null,
      canvasSnapshot: snapshot,
      status: DraftStatus.draft,
      createdAt: saved,
      lastSavedAt: saved,
    );
  }

  setUp(() {
    HydratedBloc.storage = _InMemoryStorage();
    watchDraftsUseCase = MockWatchDraftsUseCase();
    deleteDraftUseCase = MockDeleteDraftUseCase();
    resumeDraftUseCase = MockResumeDraftUseCase();
    draftsController = StreamController<List<Draft>>.broadcast();
    when(() => watchDraftsUseCase()).thenAnswer((_) => draftsController.stream);

    getIt
      ..registerFactory<DraftsListBloc>(
        () => DraftsListBloc(
          watchDraftsUseCase,
          deleteDraftUseCase,
          resumeDraftUseCase,
        ),
      )
      ..registerFactory<DraftsDisclosureSeenCubit>(
        DraftsDisclosureSeenCubit.new,
      );
  });

  tearDown(() async {
    await draftsController.close();
    await getIt.reset();
  });

  Widget wrap() {
    return MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      home: const DraftsPage(),
    );
  }

  testWidgets('shows a loading indicator before the first watchAll emission', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'shows the empty state once watchAll emits an empty list, with no '
    'first-run disclosure sheet in the way (already marked seen)',
    (tester) async {
      DraftsDisclosureSeenCubit().markSeen();

      await tester.pumpWidget(wrap());
      draftsController.add([]);
      await tester.pumpAndSettle();

      expect(find.text('No drafts yet'), findsOneWidget);
      expect(find.byKey(const Key('drafts_list')), findsNothing);
    },
  );

  testWidgets('shows the first-run disclosure sheet the first time the page is '
      'reached, and marks it seen once dismissed', (tester) async {
    await tester.pumpWidget(wrap());
    draftsController.add([]);
    await tester.pumpAndSettle();

    expect(find.text('Drafts are stored on this device'), findsOneWidget);
    expect(DraftsDisclosureSeenCubit().state, isFalse);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.text('Drafts are stored on this device'), findsNothing);
    expect(DraftsDisclosureSeenCubit().state, isTrue);
  });

  testWidgets('renders one card per draft, most-recently-saved order '
      "preserved from the bloc's state (this page doesn't re-sort)", (
    tester,
  ) async {
    DraftsDisclosureSeenCubit().markSeen();

    await tester.pumpWidget(wrap());
    draftsController.add([
      draft('d1', inputText: 'A newer idea about summer sales'),
      draft('d2', inputText: 'An older idea about a product launch'),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('drafts_list')), findsOneWidget);
    expect(
      find.textContaining('A newer idea about summer sales'),
      findsOneWidget,
    );
    expect(
      find.textContaining('An older idea about a product launch'),
      findsOneWidget,
    );
    expect(find.text('Saved just now'), findsNWidgets(2));
  });

  testWidgets('swiping a card and confirming dispatches DraftDeleteRequested', (
    tester,
  ) async {
    DraftsDisclosureSeenCubit().markSeen();
    when(
      () => deleteDraftUseCase(any()),
    ).thenAnswer((_) async => const Result.ok(null));

    await tester.pumpWidget(wrap());
    draftsController.add([draft('d1', inputText: 'An idea to delete')]);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('dismissible_d1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    // Dismissible's confirmDismiss shows the confirm sheet before it
    // actually lets the swipe complete.
    expect(find.text('Delete this draft?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => deleteDraftUseCase('d1')).called(1);
  });

  testWidgets(
    'swiping a card and cancelling leaves the draft in place, with no '
    'delete dispatched',
    (tester) async {
      DraftsDisclosureSeenCubit().markSeen();

      await tester.pumpWidget(wrap());
      draftsController.add([draft('d1', inputText: 'An idea to keep')]);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('dismissible_d1')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('An idea to keep'), findsOneWidget);
      verifyNever(() => deleteDraftUseCase(any()));
    },
  );
}
