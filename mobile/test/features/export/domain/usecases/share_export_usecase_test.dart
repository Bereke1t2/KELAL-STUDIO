import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:kelal_studio/features/export/domain/repositories/export_repository.dart';
import 'package:kelal_studio/features/export/domain/usecases/share_export_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockExportRepository extends Mock implements ExportRepository {}

void main() {
  late MockExportRepository repository;
  late ShareExportUseCase useCase;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockExportRepository();
    useCase = ShareExportUseCase(repository);
  });

  test('delegates straight through to ExportRepository.shareImage with both '
      'the bytes and the optional caption text', () async {
    final bytes = Uint8List.fromList([4, 5, 6]);
    when(
      () => repository.shareImage(pngBytes: bytes, text: 'caption'),
    ).thenAnswer((_) async => const Result.ok(null));

    final result = await useCase(pngBytes: bytes, text: 'caption');

    expect(result.isOk, isTrue);
    verify(
      () => repository.shareImage(pngBytes: bytes, text: 'caption'),
    ).called(1);
  });

  test('propagates a failure Result unchanged', () async {
    final bytes = Uint8List(0);
    const failure = ExportFailure(
      type: ExportFailureType.shareFailed,
      message: 'share failed',
    );
    when(
      () => repository.shareImage(pngBytes: bytes),
    ).thenAnswer((_) async => const Result.err(failure));

    final result = await useCase(pngBytes: bytes);

    expect(result.isErr, isTrue);
  });
}
