import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/render_engine/render_engine.dart';

/// Renders a tiny, real, decoded [ui.Image] at runtime — same technique
/// `logo_upload_hardener_test.dart` uses, so image-bearing tests here stay
/// self-contained rather than depending on a committed binary fixture.
Future<ui.Image> _testImage(
  Color color, {
  int width = 8,
  int height = 8,
}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image background;

  setUp(() async {
    background = await _testImage(const Color(0xFFFF0000));
  });

  tearDown(() {
    background.dispose();
  });

  group('RenderEngine.exportPng', () {
    test("produces valid PNG bytes at the scene's full canvasSize", () async {
      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(64, 64),
      );

      final bytes = await RenderEngine.exportPng(scene);

      expect(bytes, isNotEmpty);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 64);
      expect(frame.image.height, 64);
      frame.image.dispose();
    });

    test(
      'does not throw when the scene has no logo (the common case)',
      () async {
        final scene = CanvasScene(
          backgroundImage: background,
          canvasSize: const Size(32, 32),
        );

        expect(scene.logo, isNull);
        await expectLater(RenderEngine.exportPng(scene), completes);
      },
    );

    test(
      'composites a LogoLayer without throwing and preserves canvasSize',
      () async {
        final logoImage = await _testImage(
          const Color(0xFF00FF00),
          width: 4,
          height: 4,
        );
        addTearDown(logoImage.dispose);

        final scene = CanvasScene(
          backgroundImage: background,
          canvasSize: const Size(64, 64),
          logo: LogoLayer(
            image: logoImage,
            normalizedOffset: const Offset(0.05, 0.05),
            normalizedWidth: 0.2,
          ),
        );

        final bytes = await RenderEngine.exportPng(scene);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 64);
        expect(frame.image.height, 64);
        frame.image.dispose();
      },
    );

    test('renders a text layer without throwing', () async {
      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(64, 64),
        textLayers: const [
          TextLayer(
            id: 'layer-1',
            text: 'Hello',
            normalizedOffset: Offset(0.1, 0.1),
            normalizedMaxWidth: 0.8,
            style: TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
          ),
        ],
      );

      await expectLater(RenderEngine.exportPng(scene), completes);
    });
  });

  group('CanvasScenePainter', () {
    test('shouldRepaint is false for the identical scene instance', () {
      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(64, 64),
      );
      final painter = CanvasScenePainter(scene);

      expect(painter.shouldRepaint(CanvasScenePainter(scene)), isFalse);
    });

    test('shouldRepaint is true for a different scene instance', () {
      final sceneA = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(64, 64),
      );
      final sceneB = sceneA.copyWith(textLayers: const []);
      final painter = CanvasScenePainter(sceneA);

      // copyWith still returns a new CanvasScene instance even with
      // logically-equal fields — CanvasScene has no `==` override, so
      // CanvasScenePainter.shouldRepaint is deliberately identity-based
      // (see its own doc comment).
      expect(painter.shouldRepaint(CanvasScenePainter(sceneB)), isTrue);
    });
  });
}
