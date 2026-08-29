import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/domain/usecases/save_export_to_gallery_usecase.dart';
import 'package:kelal_studio/features/export/domain/usecases/share_export_usecase.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_bloc.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_event.dart';
import 'package:kelal_studio/features/export/presentation/bloc/export_state.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveExportToGalleryUseCase extends Mock
    implements SaveExportToGalleryUseCase {}

class MockShareExportUseCase extends Mock implements ShareExportUseCase {}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSaveExportToGalleryUseCase saveExportToGalleryUseCase;
  late MockShareExportUseCase shareExportUseCase;
  late ui.Image background;
  late CanvasScene scene;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    saveExportToGalleryUseCase = MockSaveExportToGalleryUseCase();
    shareExportUseCase = MockShareExportUseCase();
    background = await _testImage();
    scene = CanvasScene(
      backgroundImage: background,
      canvasSize: const Size(4, 4),
    );
  });

  tearDown(() {
    background.dispose();
  });

  ExportBloc buildBloc() =>
      ExportBloc(saveExportToGalleryUseCase, shareExportUseCase);

  group('ExportGallerySaveRequested', () {
    blocTest<ExportBloc, ExportState>(
      'renders the scene via RenderEngine.exportPng and emits '
      '[GallerySaveInProgress, GallerySaveSuccess] on a successful save',
      setUp: () {
        when(
          () => saveExportToGalleryUseCase(any()),
        ).thenAnswer((_) async => const Result.ok(null));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(ExportGallerySaveRequested(scene)),
      // RenderEngine.exportPng does a real `dart:ui` picture-record ->
      // toImage -> PNG-encode round trip (not a mocked, already-resolved
      // Future like the use-case mocks elsewhere in this file), which
      // genuinely needs a few real event-loop turns to complete — without
      // an explicit wait, bloc_test's default (effectively zero extra
      // delay before asserting) closes the bloc mid-encode and only the
      // first emitted state is ever observed.
      wait: const Duration(milliseconds: 200),
      expect: () => const [
        ExportGallerySaveInProgress(),
        ExportGallerySaveSuccess(),
      ],
      verify: (_) {
        // The bloc must pass *some* rendered PNG bytes through — exact byte
        // equality isn't asserted (that's RenderEngine's own concern, see
        // render_engine_test.dart), just that this bloc is the one that
        // calls exportPng and forwards its output.
        verify(() => saveExportToGalleryUseCase(any())).called(1);
      },
    );

    blocTest<ExportBloc, ExportState>(
      'emits GallerySaveFailure with the mapped type/message on failure',
      setUp: () {
        when(() => saveExportToGalleryUseCase(any())).thenAnswer(
          (_) async => const Result.err(
            ExportFailure(
              type: ExportFailureType.galleryPermissionDenied,
              message: 'denied',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(ExportGallerySaveRequested(scene)),
      wait: const Duration(milliseconds: 200),
      expect: () => const [
        ExportGallerySaveInProgress(),
        ExportGallerySaveFailure(
          ExportFailureType.galleryPermissionDenied,
          'denied',
        ),
      ],
    );

    blocTest<ExportBloc, ExportState>(
      'droppable transformer: a second gallery-save request fired while '
      'the first is still in flight is ignored — the structural fix for a '
      'double-tap triggering two concurrent gallery writes',
      setUp: () {
        when(() => saveExportToGalleryUseCase(any())).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const Result.ok(null);
        });
      },
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(ExportGallerySaveRequested(scene))
          ..add(ExportGallerySaveRequested(scene));
      },
      wait: const Duration(milliseconds: 250),
      expect: () => const [
        ExportGallerySaveInProgress(),
        ExportGallerySaveSuccess(),
      ],
      verify: (_) {
        verify(() => saveExportToGalleryUseCase(any())).called(1);
      },
    );
  });

  group('ExportShareRequested', () {
    blocTest<ExportBloc, ExportState>(
      'renders the scene and emits [ShareInProgress, ShareSuccess] once '
      'the share sheet has been invoked, forwarding the caption text',
      setUp: () {
        when(
          () => shareExportUseCase(
            pngBytes: any(named: 'pngBytes'),
            text: 'my caption',
          ),
        ).thenAnswer((_) async => const Result.ok(null));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        ExportShareRequested(scene: scene, captionText: 'my caption'),
      ),
      // See the gallery-save success test's comment on why this needs an
      // explicit wait — same real RenderEngine.exportPng round trip.
      wait: const Duration(milliseconds: 200),
      expect: () => const [ExportShareInProgress(), ExportShareSuccess()],
      verify: (_) {
        verify(
          () => shareExportUseCase(
            pngBytes: any(named: 'pngBytes'),
            text: 'my caption',
          ),
        ).called(1);
      },
    );

    blocTest<ExportBloc, ExportState>(
      'emits ShareFailure with the mapped type/message on failure',
      setUp: () {
        when(
          () => shareExportUseCase(
            pngBytes: any(named: 'pngBytes'),
            text: any(named: 'text'),
          ),
        ).thenAnswer(
          (_) async => const Result.err(
            ExportFailure(
              type: ExportFailureType.shareFailed,
              message: 'failed',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(ExportShareRequested(scene: scene)),
      wait: const Duration(milliseconds: 200),
      expect: () => const [
        ExportShareInProgress(),
        ExportShareFailure(ExportFailureType.shareFailed, 'failed'),
      ],
    );

    blocTest<ExportBloc, ExportState>(
      'droppable transformer: a second share request fired while the '
      'first is still in flight is ignored — prevents stacking two native '
      'Share Sheets from a double tap',
      setUp: () {
        when(
          () => shareExportUseCase(
            pngBytes: any(named: 'pngBytes'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const Result.ok(null);
        });
      },
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(ExportShareRequested(scene: scene))
          ..add(ExportShareRequested(scene: scene));
      },
      wait: const Duration(milliseconds: 250),
      expect: () => const [ExportShareInProgress(), ExportShareSuccess()],
      verify: (_) {
        verify(
          () => shareExportUseCase(
            pngBytes: any(named: 'pngBytes'),
            text: any(named: 'text'),
          ),
        ).called(1);
      },
    );
  });
}
