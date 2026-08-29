import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft.dart';
import 'package:kelal_studio/features/drafts/domain/usecases/save_draft_usecase.dart';
import 'package:kelal_studio/features/drafts/presentation/cubit/draft_autosave_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveDraftUseCase extends Mock implements SaveDraftUseCase {}

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

// draftAutosaveDebounce is a real 2-second Duration, and DraftAutosaveCubit's
// save path genuinely encodes a PNG via dart:ui (a real engine round trip,
// not a pure-Dart Future chain) — package:fake_async's virtual clock can
// fast-forward Timers but not that native completion, so these tests wait
// in real time rather than faking it. `_wait`/`_shortWait` name the two
// durations these tests actually need, both comfortably bounded.
Future<void> _wait() =>
    Future<void>.delayed(draftAutosaveDebounce + const Duration(seconds: 1));

Future<void> _shortWait() =>
    Future<void>.delayed(draftAutosaveDebounce - const Duration(seconds: 1));

void main() {
  late MockSaveDraftUseCase saveDraftUseCase;
  late ui.Image background;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(FakeDraft());
    // DraftCanvasSnapshot.fromCanvasScene calls path_provider's
    // getApplicationDocumentsDirectory() to know where to write the PNG —
    // outside a widget test binding there's no real platform channel
    // behind it, so it's mocked directly here (no path_provider_platform_
    // interface dependency needed just for this one method-channel stub).
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
    saveDraftUseCase = MockSaveDraftUseCase();
    background = await _testImage();
  });

  CanvasScene scene() =>
      CanvasScene(backgroundImage: background, canvasSize: const Size(8, 8));

  test(
    'a scene change does not save before draftAutosaveDebounce elapses',
    () async {
      when(
        () => saveDraftUseCase(any()),
      ).thenAnswer((_) async => const Result.ok(null));
      final cubit = DraftAutosaveCubit(saveDraftUseCase)
        ..sceneChanged(scene(), inputText: 'An idea');
      await _shortWait();

      verifyNever(() => saveDraftUseCase(any()));
      expect(cubit.state, DraftAutosaveStatus.idle);

      await cubit.close();
    },
  );

  test('restarting the debounce on every scene change means only the LAST '
      'change in a burst is ever saved', () async {
    when(
      () => saveDraftUseCase(any()),
    ).thenAnswer((_) async => const Result.ok(null));
    final cubit = DraftAutosaveCubit(saveDraftUseCase)
      ..sceneChanged(scene(), inputText: 'First');
    await _shortWait();
    cubit.sceneChanged(scene(), inputText: 'Second');
    await _shortWait();
    cubit.sceneChanged(scene(), inputText: 'Third — the only one saved');
    await _wait();

    final captured = verify(() => saveDraftUseCase(captureAny())).captured;
    expect(captured, hasLength(1));
    expect((captured.single as Draft).inputText, 'Third — the only one saved');

    await cubit.close();
  });

  test('once the debounce elapses, emits saving then saved on a successful '
      'save', () async {
    when(
      () => saveDraftUseCase(any()),
    ).thenAnswer((_) async => const Result.ok(null));
    final cubit = DraftAutosaveCubit(saveDraftUseCase);
    final states = <DraftAutosaveStatus>[];
    cubit.stream.listen(states.add);

    cubit.sceneChanged(scene(), inputText: 'An idea');
    await _wait();

    expect(states, [DraftAutosaveStatus.saving, DraftAutosaveStatus.saved]);

    await cubit.close();
  });

  test('emits failed when SaveDraftUseCase returns a Result.err', () async {
    when(
      () => saveDraftUseCase(any()),
    ).thenAnswer((_) async => const Result.err(CacheFailure('Storage full')));
    final cubit = DraftAutosaveCubit(saveDraftUseCase);
    final states = <DraftAutosaveStatus>[];
    cubit.stream.listen(states.add);

    cubit.sceneChanged(scene(), inputText: 'An idea');
    await _wait();

    expect(states, [DraftAutosaveStatus.saving, DraftAutosaveStatus.failed]);

    await cubit.close();
  });

  test('emits failed rather than propagating when the PNG-encode step throws '
      '(e.g. an already-disposed background image)', () async {
    final cubit = DraftAutosaveCubit(saveDraftUseCase);
    final states = <DraftAutosaveStatus>[];
    cubit.stream.listen(states.add);

    background.dispose();
    final disposedScene = CanvasScene(
      backgroundImage: background,
      canvasSize: const Size(8, 8),
    );

    cubit.sceneChanged(disposedScene, inputText: 'An idea');
    await _wait();

    expect(states, [DraftAutosaveStatus.saving, DraftAutosaveStatus.failed]);
    verifyNever(() => saveDraftUseCase(any()));

    await cubit.close();
  });

  test('repeated autosaves within one Cubit instance reuse the same localId, '
      'and only the first save fixes createdAt', () async {
    when(
      () => saveDraftUseCase(any()),
    ).thenAnswer((_) async => const Result.ok(null));
    final cubit = DraftAutosaveCubit(saveDraftUseCase)
      ..sceneChanged(scene(), inputText: 'First save');
    await _wait();
    cubit.sceneChanged(scene(), inputText: 'Second save');
    await _wait();

    final captured = verify(
      () => saveDraftUseCase(captureAny()),
    ).captured.cast<Draft>();
    expect(captured, hasLength(2));
    expect(captured[0].localId, captured[1].localId);
    expect(captured[0].createdAt, captured[1].createdAt);
    expect(captured[1].lastSavedAt.isAfter(captured[0].lastSavedAt), isTrue);

    await cubit.close();
  });

  test(
    'close cancels a pending debounce timer — no save fires after',
    () async {
      when(
        () => saveDraftUseCase(any()),
      ).thenAnswer((_) async => const Result.ok(null));
      final cubit = DraftAutosaveCubit(saveDraftUseCase)
        ..sceneChanged(scene(), inputText: 'An idea');
      await cubit.close();
      await _wait();

      verifyNever(() => saveDraftUseCase(any()));
    },
  );
}
