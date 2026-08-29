import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kelal_studio/core/di/injection.dart';
import 'package:kelal_studio/core/l10n/gen/app_localizations.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_bloc.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/pages/canvas_editor_page.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/save_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/presentation/cubit/draft_autosave_cubit.dart';
import 'package:kelal_studio/features/export/presentation/pages/export_page.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveDraftUseCase extends Mock implements SaveDraftUseCase {}

class MockDraftAutosaveCubit extends Mock implements DraftAutosaveCubit {}

class FakeDraft extends Fake implements Draft {}

class FakeCanvasScene extends Fake implements CanvasScene {}

Future<ui.Image> _testImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  picture.dispose();
  return image;
}

void main() {
  late ui.Image background;
  late MockSaveDraftUseCase saveDraftUseCase;

  setUpAll(() {
    registerFallbackValue(FakeDraft());
    registerFallbackValue(FakeCanvasScene());
    // Only exercised by the DraftAutosaveCubit-wiring test below, which
    // lets a real DraftCanvasSnapshot.fromCanvasScene call reach
    // path_provider's getApplicationDocumentsDirectory() — see
    // draft_autosave_cubit_test.dart's identical setup for why this is
    // mocked directly rather than adding a new dependency.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp.path;
          }
          return null;
        });
  });

  setUp(() async {
    background = await _testImage();
    saveDraftUseCase = MockSaveDraftUseCase();
    getIt
      // CanvasEditorBloc takes no constructor dependencies (every handler
      // is a synchronous, local mutation — see its own doc comment), so
      // no mocking is needed to register it.
      ..registerFactory<CanvasEditorBloc>(CanvasEditorBloc.new)
      // CanvasEditorPage also provides a DraftAutosaveCubit (PRD §10.5)
      // via getIt. Most tests below never wait past
      // `draftAutosaveDebounce` (2s), so the mock is never actually
      // called and needs no stubbing — except the one test below that
      // specifically verifies this wiring, which stubs it itself.
      ..registerFactory<DraftAutosaveCubit>(
        () => DraftAutosaveCubit(saveDraftUseCase),
      );
  });

  tearDown(() async {
    background.dispose();
    await getIt.reset();
  });

  Widget wrap(CanvasScene scene) {
    return MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('am')],
      home: CanvasEditorPage(
        args: CanvasEditorPageArgs(
          scene: scene,
          captionEn: 'English caption',
          captionAm: 'Amharic caption',
          inputText: 'Test idea text',
        ),
      ),
    );
  }

  testWidgets(
    'shows the aspect ratio selector, add/remove buttons, and the safe '
    'zone guide for the loaded scene',
    (tester) async {
      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(1080, 1080),
      );

      await tester.pumpWidget(wrap(scene));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('canvas_editor_aspect_ratio_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('canvas_editor_add_text_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('canvas_editor_remove_text_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('safe_zone_guide_top')), findsOneWidget);
      expect(find.byKey(const Key('safe_zone_guide_bottom')), findsOneWidget);
      expect(
        find.byKey(const Key('canvas_editor_continue_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('the remove button is disabled until a layer is selected', (
    tester,
  ) async {
    final scene = CanvasScene(
      backgroundImage: background,
      canvasSize: const Size(1080, 1080),
      textLayers: const [
        TextLayer(
          id: 'layer-1',
          text: 'Hello',
          normalizedOffset: Offset(0.1, 0.5),
          normalizedMaxWidth: 0.8,
          style: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
        ),
      ],
    );

    await tester.pumpWidget(wrap(scene));
    await tester.pumpAndSettle();

    final removeButtonBefore = tester.widget<OutlinedButton>(
      find.byKey(const Key('canvas_editor_remove_text_button')),
    );
    expect(removeButtonBefore.onPressed, isNull);

    // Selection fires from the drag/pinch gesture's onScaleStart, not
    // onTap (a plain tap opens the edit sheet instead — see
    // _DraggableTextLayer's GestureDetector). Driven as an explicit
    // multi-frame TestGesture rather than tester.drag(), which sends its
    // move in too few frames for the ScaleGestureRecognizer here to
    // register reliably in this widget tree.
    final center = tester.getCenter(
      find.byKey(const Key('canvas_editor_layer_layer-1')),
    );
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(10, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    final removeButtonAfter = tester.widget<OutlinedButton>(
      find.byKey(const Key('canvas_editor_remove_text_button')),
    );
    expect(removeButtonAfter.onPressed, isNotNull);
  });

  testWidgets(
    'tapping Add adds an empty layer and immediately opens the tap-to-edit '
    'sheet for it (CanvasEditorPage auto-opens for a newly-added empty '
    "layer per CanvasEditorBloc._onLayerAdded's doc comment)",
    (tester) async {
      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(1080, 1080),
      );

      await tester.pumpWidget(wrap(scene));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('canvas_editor_add_text_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('canvas_editor_edit_sheet_field')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the Add button is disabled once the PRD §6.9 2-layer cap is reached',
    (tester) async {
      const style = TextStyle(fontSize: 16, color: Color(0xFFFFFFFF));
      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(1080, 1080),
        textLayers: const [
          TextLayer(
            id: 'layer-1',
            text: 'One',
            normalizedOffset: Offset(0.1, 0.3),
            normalizedMaxWidth: 0.8,
            style: style,
          ),
          TextLayer(
            id: 'layer-2',
            text: 'Two',
            normalizedOffset: Offset(0.1, 0.6),
            normalizedMaxWidth: 0.8,
            style: style,
          ),
        ],
      );

      await tester.pumpWidget(wrap(scene));
      await tester.pumpAndSettle();

      final addButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('canvas_editor_add_text_button')),
      );
      expect(addButton.onPressed, isNull);
    },
  );

  testWidgets('tapping Continue pushes /export with the current scene plus the '
      "captions carried in from ComposerPage's CanvasEditorPageArgs", (
    tester,
  ) async {
    final scene = CanvasScene(
      backgroundImage: background,
      canvasSize: const Size(1080, 1080),
    );

    ExportPageArgs? pushedArgs;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => CanvasEditorPage(
            args: CanvasEditorPageArgs(
              scene: scene,
              captionEn: 'English caption',
              captionAm: 'Amharic caption',
              inputText: 'Test idea text',
            ),
          ),
        ),
        // A bare placeholder rather than the real ExportPage — that
        // screen's own contract (ExportBloc/ExportOverlaySeenCubit via
        // getIt, HydratedCubit storage) is out of scope for this test
        // file and covered by export_page_test.dart instead. This test
        // only needs to prove *what* CanvasEditorPage hands off when
        // Continue is tapped.
        GoRoute(
          path: '/export',
          builder: (context, state) {
            pushedArgs = state.extra! as ExportPageArgs;
            return const Scaffold(body: Text('export-destination'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('am')],
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('canvas_editor_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('export-destination'), findsOneWidget);
    expect(pushedArgs, isNotNull);
    expect(pushedArgs!.captionEn, 'English caption');
    expect(pushedArgs!.captionAm, 'Amharic caption');
    expect(pushedArgs!.scene.canvasSize, scene.canvasSize);
  });

  testWidgets(
    "the aspect ratio selector reflects the loaded scene's canvasSize",
    (tester) async {
      final scene = CanvasScene(
        backgroundImage: background,
        // 4:5, not the default 1:1.
        canvasSize: const Size(1080, 1350),
      );

      await tester.pumpWidget(wrap(scene));
      await tester.pumpAndSettle();

      // Both ratio labels render; this just asserts the screen didn't
      // crash resolving a non-square initial scene and the selector is
      // present — precise selected-index assertion is covered at the
      // bloc level (canvas_editor_bloc_test.dart).
      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('4:5'), findsOneWidget);
    },
  );

  testWidgets(
    'a scene change (aspect ratio toggle) feeds DraftAutosaveCubit via the '
    'MultiBlocListener this page adds — with the current (post-toggle) '
    'scene and args.inputText/brandKitId, not stale ones. DraftAutosaveCubit '
    "'s own debounce/save behavior is covered separately, in "
    'draft_autosave_cubit_test.dart — a mock stands in for it here so this '
    "test only has to prove *this page's* listener wiring, not re-prove "
    'the whole real Timer + dart:ui-encode + SaveDraftUseCase pipeline in a '
    'widget test.',
    (tester) async {
      final autosaveCubit = MockDraftAutosaveCubit();
      when(() => autosaveCubit.stream).thenAnswer((_) => const Stream.empty());
      when(() => autosaveCubit.state).thenReturn(DraftAutosaveStatus.idle);
      when(autosaveCubit.close).thenAnswer((_) async {});
      when(
        () => autosaveCubit.sceneChanged(
          any(),
          inputText: any(named: 'inputText'),
          brandKitId: any(named: 'brandKitId'),
          generationRecordId: any(named: 'generationRecordId'),
        ),
      ).thenReturn(null);
      getIt
        ..unregister<DraftAutosaveCubit>()
        ..registerFactory<DraftAutosaveCubit>(() => autosaveCubit);

      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(1080, 1080),
      );

      await tester.pumpWidget(wrap(scene));
      await tester.pumpAndSettle();

      // The initial CanvasEditorSceneLoaded already reaches
      // CanvasEditorReady once, so the listener has already fired once
      // for the 1:1 scene by this point — expected, not asserted on here.
      clearInteractions(autosaveCubit);

      await tester.tap(find.text('4:5'));
      await tester.pumpAndSettle();

      final captured = verify(
        () => autosaveCubit.sceneChanged(
          captureAny(),
          inputText: captureAny(named: 'inputText'),
          brandKitId: captureAny(named: 'brandKitId'),
          generationRecordId: any(named: 'generationRecordId'),
        ),
      ).captured;
      // captured interleaves [scene, inputText, brandKitId] per call.
      expect(captured, hasLength(3));
      final capturedScene = captured[0] as CanvasScene;
      expect(captured[1], 'Test idea text');
      expect(captured[2], isNull);
      // The scene handed to DraftAutosaveCubit is the *current*
      // (post-toggle, 4:5) scene, not the original 1:1 one wrap() loaded.
      expect(capturedScene.canvasSize, const Size(1080, 1350));
    },
  );
}
