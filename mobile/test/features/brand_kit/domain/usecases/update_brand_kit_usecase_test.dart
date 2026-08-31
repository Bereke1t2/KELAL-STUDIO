import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/update_brand_kit_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockBrandKitRepository extends Mock implements BrandKitRepository {}

void main() {
  late MockBrandKitRepository repository;
  late UpdateBrandKitUseCase useCase;

  setUp(() {
    repository = MockBrandKitRepository();
    useCase = UpdateBrandKitUseCase(repository);
  });

  final brandKit = BrandKit(
    id: 'brand-kit-1',
    brandName: 'Updated Business',
    logoAssetId: 'asset-1',
    primaryColorHex: '#855312',
    secondaryColorHex: '#C6821F',
    toneOfVoice: 'Friendly',
    contactInfo: 'hello@demo.app',
    updatedAt: DateTime.utc(2026),
  );

  test(
    'delegates to BrandKitRepository.updateBrandKit with the given draft',
    () async {
      when(
        () => repository.updateBrandKit(brandKit),
      ).thenAnswer((_) async => Result.ok(brandKit));

      final result = await useCase(brandKit);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, brandKit);
      verify(() => repository.updateBrandKit(brandKit)).called(1);
    },
  );

  test('propagates a failure result unchanged', () async {
    const failure = ApiFailure(
      type: ApiErrorType.validationError,
      message: 'Please check your input and try again.',
    );
    when(
      () => repository.updateBrandKit(brandKit),
    ).thenAnswer((_) async => const Result.err(failure));

    final result = await useCase(brandKit);

    expect(result.isErr, isTrue);
  });
}
