import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/upload_brand_logo_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockBrandKitRepository extends Mock implements BrandKitRepository {}

void main() {
  late MockBrandKitRepository repository;
  late UploadBrandLogoUseCase useCase;

  setUp(() {
    repository = MockBrandKitRepository();
    useCase = UploadBrandLogoUseCase(repository);
  });

  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  test(
    'delegates to BrandKitRepository.uploadLogo and returns the new asset id',
    () async {
      when(
        () => repository.uploadLogo(
          bytes: bytes,
          filename: 'logo.png',
          mimeType: 'image/png',
        ),
      ).thenAnswer((_) async => const Result.ok('asset-42'));

      final result = await useCase(
        bytes: bytes,
        filename: 'logo.png',
        mimeType: 'image/png',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 'asset-42');
      verify(
        () => repository.uploadLogo(
          bytes: bytes,
          filename: 'logo.png',
          mimeType: 'image/png',
        ),
      ).called(1);
    },
  );

  test('propagates a failure result unchanged', () async {
    const failure = UnexpectedFailure(
      'Something went wrong. Please try again.',
    );
    when(
      () => repository.uploadLogo(
        bytes: bytes,
        filename: 'logo.png',
        mimeType: 'image/png',
      ),
    ).thenAnswer((_) async => const Result.err(failure));

    final result = await useCase(
      bytes: bytes,
      filename: 'logo.png',
      mimeType: 'image/png',
    );

    expect(result.isErr, isTrue);
  });
}
