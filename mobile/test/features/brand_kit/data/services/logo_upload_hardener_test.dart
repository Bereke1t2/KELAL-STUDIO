import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Canvas, Color, Paint, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/features/brand_kit/data/services/logo_upload_hardener.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/logo_validation_failure.dart';

/// Renders a tiny, real, decodable PNG at runtime (via `dart:ui`) rather
/// than committing a binary fixture — [LogoUploadHardener] genuinely needs
/// bytes that `ui.instantiateImageCodec` can decode, and this keeps the
/// test self-contained.
Future<Uint8List> _validPngBytes({int width = 8, int height = 8}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hardener = LogoUploadHardener();

  test('rejects an empty byte list', () async {
    final result = await hardener.harden(Uint8List(0));

    expect(result.isErr, isTrue);
    expect(result.valueOrNull, isNull);
  });

  test('rejects a raw pick larger than the max input size', () async {
    final oversized = Uint8List(LogoUploadHardener.maxInputBytes + 1);

    final result = await hardener.harden(oversized);

    expect(result.isErr, isTrue);
    result.when(
      ok: (_) => fail('expected a LogoValidationFailure'),
      err: (failure) => expect(failure, isA<LogoValidationFailure>()),
    );
  });

  test('rejects bytes that are not a decodable image', () async {
    final garbage = Uint8List.fromList([1, 2, 3, 4, 5]);

    final result = await hardener.harden(garbage);

    expect(result.isErr, isTrue);
  });

  test(
    're-encodes a small, already-within-bounds image to PNG bytes',
    () async {
      final original = await _validPngBytes();

      final result = await hardener.harden(original);

      expect(result.isOk, isTrue);
      final hardened = result.valueOrNull!;
      expect(hardened, isNotEmpty);
      // PNG signature — proves the output really is PNG-encoded, not a
      // pass-through of the input bytes.
      expect(hardened.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
    },
  );

  test('downscales an image whose dimensions exceed maxDimensionPx', () async {
    final oversizedDimensions = await _validPngBytes(
      width: LogoUploadHardener.maxDimensionPx + 200,
      height: 100,
    );

    final result = await hardener.harden(oversizedDimensions);

    expect(result.isOk, isTrue);
    final hardened = result.valueOrNull!;
    final codec = await ui.instantiateImageCodec(hardened);
    final frame = await codec.getNextFrame();
    expect(
      frame.image.width,
      lessThanOrEqualTo(LogoUploadHardener.maxDimensionPx),
    );
    frame.image.dispose();
  });
}
