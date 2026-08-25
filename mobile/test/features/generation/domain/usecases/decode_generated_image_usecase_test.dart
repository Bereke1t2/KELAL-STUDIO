import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/generation/data/services/network_image_decoder.dart';
import 'package:kelal_studio/features/generation/domain/usecases/decode_generated_image_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockNetworkImageDecoder extends Mock implements NetworkImageDecoder {}

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

  late MockNetworkImageDecoder decoder;
  late DecodeGeneratedImageUseCase useCase;

  setUp(() {
    decoder = MockNetworkImageDecoder();
    useCase = DecodeGeneratedImageUseCase(decoder);
  });

  test('delegates the url to NetworkImageDecoder.decode and returns its '
      'result unchanged on success', () async {
    final image = await _testImage();
    addTearDown(image.dispose);
    when(
      () => decoder.decode('https://picsum.photos/seed/1/1080/1080'),
    ).thenAnswer((_) async => Result.ok(image));

    final outcome = await useCase('https://picsum.photos/seed/1/1080/1080');

    expect(outcome.valueOrNull, same(image));
    verify(
      () => decoder.decode('https://picsum.photos/seed/1/1080/1080'),
    ).called(1);
  });

  test('propagates a decode failure unchanged', () async {
    when(() => decoder.decode('https://bad-url')).thenAnswer(
      (_) async => const Result.err(
        UnexpectedFailure("Couldn't load the generated image."),
      ),
    );

    final outcome = await useCase('https://bad-url');

    expect(outcome.isErr, isTrue);
  });
}
