import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/render_engine/canvas_scene.dart';
import 'package:kelal_studio/core/theme/app_typography.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';
import 'package:kelal_studio/features/drafts/domain/entities/draft_canvas_snapshot.dart';
import 'package:mocktail/mocktail.dart';

class MockBrandKitRepository extends Mock implements BrandKitRepository {}

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
  late MockBrandKitRepository brandKitRepository;
  late ui.Image background;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // fromCanvasScene calls path_provider's
    // getApplicationDocumentsDirectory() to know where to write the PNG —
    // see draft_autosave_cubit_test.dart's identical setup for why this is
    // mocked directly rather than pulling in path_provider_platform_
    // interface as a new dependency.
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
    brandKitRepository = MockBrandKitRepository();
    background = await _testImage();
  });

  group('fromCanvasScene + toCanvasScene round trip', () {
    test('preserves canvas size and every text layer field, including the '
        'fixed Ethiopic line-height — RenderEngine.paint uses TextLayer.style '
        'verbatim, so a resumed draft must carry the same '
        'AppTypography.lineHeightMultiplier every live-edited layer does, not '
        "Flutter's default line-height", () async {
      when(
        brandKitRepository.getBrandKit,
      ).thenAnswer((_) async => const Result.err(CacheFailure('none')));

      final layer = TextLayer(
        id: 'layer-1',
        text: 'Fresh Produce Weekly',
        normalizedOffset: const Offset(0.1, 0.2),
        normalizedMaxWidth: 0.8,
        style: AppTypography.title.copyWith(color: const Color(0xFFFF00FF)),
        textAlign: TextAlign.center,
      );
      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(1080, 1350),
        textLayers: [layer],
      );

      final snapshot = await DraftCanvasSnapshot.fromCanvasScene(
        scene,
        localId: 'draft-1',
      );
      final rebuilt = await snapshot.toCanvasScene(
        brandKitRepository: brandKitRepository,
      );

      expect(rebuilt.canvasSize, const Size(1080, 1350));
      expect(rebuilt.textLayers, hasLength(1));

      final rebuiltLayer = rebuilt.textLayers.single;
      expect(rebuiltLayer.id, 'layer-1');
      expect(rebuiltLayer.text, 'Fresh Produce Weekly');
      expect(rebuiltLayer.normalizedOffset, const Offset(0.1, 0.2));
      expect(rebuiltLayer.normalizedMaxWidth, 0.8);
      expect(rebuiltLayer.textAlign, TextAlign.center);
      expect(rebuiltLayer.style.fontSize, AppTypography.title.fontSize);
      expect(rebuiltLayer.style.fontWeight, AppTypography.title.fontWeight);
      expect(rebuiltLayer.style.color, const Color(0xFFFF00FF));
      // The actual regression this test exists to catch.
      expect(rebuiltLayer.style.height, AppTypography.lineHeightMultiplier);

      rebuilt.backgroundImage.dispose();
    });

    test('the logo is always dropped on resume — a real, documented gap, not '
        'a crash — even when a brand kit with a logo asset id resolves '
        'successfully', () async {
      when(brandKitRepository.getBrandKit).thenAnswer(
        (_) async => Result.ok(
          BrandKit(
            id: 'brand-kit-1',
            brandName: 'Demo Business',
            logoAssetId: 'asset-1',
            primaryColorHex: '#855312',
            secondaryColorHex: '#C6821F',
            toneOfVoice: '',
            contactInfo: '',
            updatedAt: DateTime.utc(2026),
          ),
        ),
      );

      final scene = CanvasScene(
        backgroundImage: background,
        canvasSize: const Size(1080, 1080),
        logo: LogoLayer(
          image: background,
          normalizedOffset: const Offset(0.05, 0.05),
          normalizedWidth: 0.2,
        ),
      );

      final snapshot = await DraftCanvasSnapshot.fromCanvasScene(
        scene,
        localId: 'draft-2',
      );
      expect(snapshot.logo, isNotNull);

      final rebuilt = await snapshot.toCanvasScene(
        brandKitRepository: brandKitRepository,
      );

      expect(rebuilt.logo, isNull);
      verify(brandKitRepository.getBrandKit).called(1);

      rebuilt.backgroundImage.dispose();
    });

    test(
      'a scene with no text layers and no logo round-trips cleanly',
      () async {
        when(
          brandKitRepository.getBrandKit,
        ).thenAnswer((_) async => const Result.err(CacheFailure('none')));

        final scene = CanvasScene(
          backgroundImage: background,
          canvasSize: const Size(1080, 1080),
        );

        final snapshot = await DraftCanvasSnapshot.fromCanvasScene(
          scene,
          localId: 'draft-3',
        );
        final rebuilt = await snapshot.toCanvasScene(
          brandKitRepository: brandKitRepository,
        );

        expect(rebuilt.textLayers, isEmpty);
        expect(rebuilt.logo, isNull);

        rebuilt.backgroundImage.dispose();
      },
    );
  });

  group('toJson/fromJson', () {
    test('DraftCanvasSnapshot round-trips through JSON unchanged', () {
      const snapshot = DraftCanvasSnapshot(
        backgroundImagePath: '/tmp/fake.png',
        canvasWidth: 1080,
        canvasHeight: 1350,
        textLayers: [
          DraftTextLayerSnapshot(
            id: 'layer-1',
            text: 'Hello',
            dx: 0.1,
            dy: 0.2,
            normalizedMaxWidth: 0.8,
            fontSize: 24,
            fontWeightIndex: 700,
            colorValue: 0xFFFFFFFF,
            textAlignIndex: 1,
          ),
        ],
        logo: DraftLogoSnapshot(dx: 0.05, dy: 0.05, normalizedWidth: 0.2),
      );

      final roundTripped = DraftCanvasSnapshot.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
      );

      expect(roundTripped, snapshot);
    });

    test('a snapshot with no logo round-trips with logo staying null', () {
      const snapshot = DraftCanvasSnapshot(
        backgroundImagePath: '/tmp/fake.png',
        canvasWidth: 1080,
        canvasHeight: 1080,
        textLayers: [],
      );

      final roundTripped = DraftCanvasSnapshot.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
      );

      expect(roundTripped.logo, isNull);
    });
  });
}
