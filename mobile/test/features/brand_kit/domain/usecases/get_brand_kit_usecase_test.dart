import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockBrandKitRepository extends Mock implements BrandKitRepository {}

void main() {
  late MockBrandKitRepository repository;
  late GetBrandKitUseCase useCase;

  setUp(() {
    repository = MockBrandKitRepository();
    useCase = GetBrandKitUseCase(repository);
  });

  final brandKit = BrandKit(
    id: 'brand-kit-1',
    brandName: 'Demo Business',
    logoAssetId: null,
    primaryColorHex: '#855312',
    secondaryColorHex: '#C6821F',
    toneOfVoice: '',
    contactInfo: '',
    updatedAt: DateTime.utc(2026),
  );

  test(
    'delegates to BrandKitRepository.getBrandKit and returns its result',
    () async {
      when(repository.getBrandKit).thenAnswer((_) async => Result.ok(brandKit));

      final result = await useCase();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, brandKit);
      verify(repository.getBrandKit).called(1);
    },
  );

  test('propagates a failure result unchanged', () async {
    const failure = UnexpectedFailure(
      'Something went wrong. Please try again.',
    );
    when(
      repository.getBrandKit,
    ).thenAnswer((_) async => const Result.err(failure));

    final result = await useCase();

    expect(result.isErr, isTrue);
  });
}
