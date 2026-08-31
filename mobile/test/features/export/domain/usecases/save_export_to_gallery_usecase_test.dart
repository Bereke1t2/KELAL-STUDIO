import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/domain/repositories/export_repository.dart';
import 'package:kelal_studio/features/export/domain/usecases/save_export_to_gallery_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockExportRepository extends Mock implements ExportRepository {}

void main() {
  late MockExportRepository repository;
  late SaveExportToGalleryUseCase useCase;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockExportRepository();
    useCase = SaveExportToGalleryUseCase(repository);
  });

  test(
    'delegates straight through to ExportRepository.saveToGallery',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(
        () => repository.saveToGallery(bytes),
      ).thenAnswer((_) async => const Result.ok(null));

      final result = await useCase(bytes);

      expect(result.isOk, isTrue);
      verify(() => repository.saveToGallery(bytes)).called(1);
    },
  );

  test('propagates a failure Result unchanged', () async {
    final bytes = Uint8List(0);
    const failure = ExportFailure(
      type: ExportFailureType.galleryWriteFailed,
      message: 'no space',
    );
    when(
      () => repository.saveToGallery(bytes),
    ).thenAnswer((_) async => const Result.err(failure));

    final result = await useCase(bytes);

    expect(result.isErr, isTrue);
  });
}
