import 'dart:ui' as ui;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/render_engine/safe_zone_constants.dart';
import 'package:kelal_studio/core/theme/app_theme.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_bloc.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_event.dart';
import 'package:kelal_studio/features/canvas_editor/presentation/bloc/canvas_editor_state.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';

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

TextLayer _layer(String id, {Offset offset = const Offset(0.1, 0.5)}) {
  return TextLayer(
    id: id,
    text: 'Hello',
    normalizedOffset: offset,
    normalizedMaxWidth: 0.8,
    style: AppTypography.body.copyWith(color: const Color(0xFFFFFFFF)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image background;
  late CanvasScene scene;

  setUp(() async {
    background = await _testImage();
    scene = CanvasScene(
      backgroundImage: background,
      canvasSize: const Size(1080, 1080),
      textLayers: [_layer('layer-1')],
    );
  });

  tearDown(() {
    background.dispose();
  });

  group('CanvasEditorBloc.normalizedDragDelta', () {
    test('divides the screen delta by the box size, not canvasSize', () {
      final delta = CanvasEditorBloc.normalizedDragDelta(
        screenDelta: const Offset(50, 25),
        boxSize: const Size(200, 100),
      );

      expect(delta.dx, closeTo(0.25, 1e-9));
      expect(delta.dy, closeTo(0.25, 1e-9));
    });

    test('returns Offset.zero for a degenerate zero-size box', () {
      final delta = CanvasEditorBloc.normalizedDragDelta(
        screenDelta: const Offset(50, 25),
        boxSize: Size.zero,
      );

      expect(delta, Offset.zero);
    });
  });

  group('CanvasEditorBloc.estimateLayerHeightFraction', () {
    test("is the layer's line height as a fraction of canvas height", () {
      final layer = _layer('layer-1');
      const canvasSize = Size(1000, 1000);
      final fraction = CanvasEditorBloc.estimateLayerHeightFraction(
        layer,
        canvasSize,
      );
      final expectedLineHeight =
          (layer.style.fontSize ?? AppTypography.body.fontSize!) *
          AppTypography.lineHeightMultiplier;

      expect(fraction, closeTo(expectedLineHeight / 1000, 1e-9));
    });

    test('returns 0 for a degenerate zero-height canvas', () {
      final fraction = CanvasEditorBloc.estimateLayerHeightFraction(
        _layer('layer-1'),
        Size.zero,
      );

      expect(fraction, 0);
    });
  });

  group('CanvasEditorSceneLoaded', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'emits CanvasEditorReady with the loaded scene and no selection',
      build: CanvasEditorBloc.new,
      act: (bloc) => bloc.add(CanvasEditorSceneLoaded(scene)),
      expect: () => [
        isA<CanvasEditorReady>()
            .having((s) => s.scene, 'scene', same(scene))
            .having((s) => s.selectedLayerId, 'selectedLayerId', isNull),
      ],
    );
  });

  group('CanvasEditorLayerSelected', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'selects the given layer id',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(const CanvasEditorLayerSelected('layer-1')),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.selectedLayerId,
          'selectedLayerId',
          'layer-1',
        ),
      ],
    );

    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'a null layerId clears the current selection',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene, selectedLayerId: 'layer-1'),
      act: (bloc) => bloc.add(const CanvasEditorLayerSelected(null)),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.selectedLayerId,
          'selectedLayerId',
          isNull,
        ),
      ],
    );
  });

  group('CanvasEditorLayerDragUpdated', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'moves the layer by the normalized drag delta when the result stays '
      'inside the safe area',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(
        const CanvasEditorLayerDragUpdated(
          layerId: 'layer-1',
          screenDelta: Offset(20, 20),
          boxSize: Size(200, 200),
        ),
      ),
      expect: () => [
        isA<CanvasEditorReady>()
            .having(
              (s) => s.scene.textLayers.first.normalizedOffset.dx,
              'moved offset.dx',
              // Starting at 0.1 + 0.1 delta.
              closeTo(0.2, 1e-9),
            )
            .having(
              (s) => s.scene.textLayers.first.normalizedOffset.dy,
              'moved offset.dy',
              // Starting at 0.5 + 0.1 delta.
              closeTo(0.6, 1e-9),
            ),
      ],
    );

    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'clamps dy into the safe area rather than letting it drag into the '
      'top obstruction band',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(
        scene: scene.copyWith(
          textLayers: [_layer('layer-1', offset: const Offset(0.1, 0.11))],
        ),
      ),
      act: (bloc) => bloc.add(
        const CanvasEditorLayerDragUpdated(
          layerId: 'layer-1',
          screenDelta: Offset(0, -100),
          boxSize: Size(1000, 1000),
        ),
      ),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.scene.textLayers.first.normalizedOffset.dy,
          'clamped dy',
          greaterThanOrEqualTo(SafeZoneConstants.topObstructionFraction),
        ),
      ],
    );

    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'clamps dx so the text box never runs off the canvas edge',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(
        const CanvasEditorLayerDragUpdated(
          layerId: 'layer-1',
          screenDelta: Offset(10000, 0),
          boxSize: Size(1000, 1000),
        ),
      ),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.scene.textLayers.first.normalizedOffset.dx,
          'clamped dx',
          closeTo(1.0 - 0.8, 1e-9),
        ),
      ],
    );

    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'is a no-op when the layer id does not exist in the scene',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(
        const CanvasEditorLayerDragUpdated(
          layerId: 'does-not-exist',
          screenDelta: Offset(20, 20),
          boxSize: Size(200, 200),
        ),
      ),
      expect: () => <CanvasEditorState>[],
    );
  });

  group('CanvasEditorLayerScaled', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'multiplies normalizedMaxWidth by the scale factor',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(
        const CanvasEditorLayerScaled(layerId: 'layer-1', scaleFactor: 1.1),
      ),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.scene.textLayers.first.normalizedMaxWidth,
          'scaled width',
          // 0.8 * 1.1 stays under the 0.95 cap, so it's unclamped here —
          // the clamp itself is covered by the next test.
          closeTo(0.8 * 1.1, 1e-9),
        ),
      ],
    );

    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'clamps the scaled width to the min/max bounds',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(
        const CanvasEditorLayerScaled(layerId: 'layer-1', scaleFactor: 10),
      ),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.scene.textLayers.first.normalizedMaxWidth,
          'clamped width',
          0.95,
        ),
      ],
    );
  });

  group('CanvasEditorLayerTextChanged', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      "updates the given layer's text",
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(
        const CanvasEditorLayerTextChanged(
          layerId: 'layer-1',
          text: 'New caption',
        ),
      ),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.scene.textLayers.first.text,
          'text',
          'New caption',
        ),
      ],
    );
  });

  group('CanvasEditorLayerAdded', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'adds an empty text layer and selects it when under the cap',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene.copyWith(textLayers: [])),
      act: (bloc) => bloc.add(const CanvasEditorLayerAdded()),
      expect: () => [
        isA<CanvasEditorReady>()
            .having((s) => s.scene.textLayers, 'textLayers', hasLength(1))
            .having((s) => s.scene.textLayers.first.text, 'text', '')
            .having((s) => s.selectedLayerId, 'selectedLayerId', isNotNull),
      ],
    );

    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'is a silent no-op past the PRD §6.9 2-layer cap',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(
        scene: scene.copyWith(
          textLayers: [_layer('layer-1'), _layer('layer-2')],
        ),
      ),
      act: (bloc) => bloc.add(const CanvasEditorLayerAdded()),
      expect: () => <CanvasEditorState>[],
    );
  });

  group('CanvasEditorLayerRemoved', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'removes the given layer',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(const CanvasEditorLayerRemoved('layer-1')),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.scene.textLayers,
          'textLayers',
          isEmpty,
        ),
      ],
    );

    blocTest<CanvasEditorBloc, CanvasEditorState>(
      'clears the selection when the removed layer was selected',
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene, selectedLayerId: 'layer-1'),
      act: (bloc) => bloc.add(const CanvasEditorLayerRemoved('layer-1')),
      expect: () => [
        isA<CanvasEditorReady>().having(
          (s) => s.selectedLayerId,
          'selectedLayerId',
          isNull,
        ),
      ],
    );
  });

  group('CanvasEditorAspectRatioChanged', () {
    blocTest<CanvasEditorBloc, CanvasEditorState>(
      "updates canvasSize to the new ratio's target size, keeping text "
      "layers' normalized coordinates unchanged",
      build: CanvasEditorBloc.new,
      seed: () => CanvasEditorReady(scene: scene),
      act: (bloc) => bloc.add(
        const CanvasEditorAspectRatioChanged(GenerationAspectRatio.fourToFive),
      ),
      expect: () => [
        isA<CanvasEditorReady>()
            .having(
              (s) => s.scene.canvasSize,
              'canvasSize',
              GenerationAspectRatio.fourToFive.canvasSize,
            )
            .having(
              (s) => s.scene.textLayers.first.normalizedOffset,
              'unchanged normalized offset',
              scene.textLayers.first.normalizedOffset,
            ),
      ],
    );
  });
}
