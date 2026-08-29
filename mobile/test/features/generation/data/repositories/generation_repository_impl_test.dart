import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/generation/data/datasources/generation_remote_data_source.dart';
import 'package:kelal_studio/features/generation/data/models/generate_image_response_dto.dart';
import 'package:kelal_studio/features/generation/data/models/generate_text_response_dto.dart';
import 'package:kelal_studio/features/generation/data/repositories/generation_repository_impl.dart';
import 'package:kelal_studio/features/generation/domain/entities/aspect_ratio.dart';
import 'package:kelal_studio/features/generation/domain/entities/content_platform.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_image_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/generation_result.dart';
import 'package:kelal_studio/features/generation/domain/entities/input_language.dart';
import 'package:mocktail/mocktail.dart';

class MockGenerationRemoteDataSource extends Mock
    implements GenerationRemoteDataSource {}

void main() {
  late MockGenerationRemoteDataSource remote;
  late GenerationRepositoryImpl repository;

  const responseDto = GenerateTextResponseDto(
    captionEn: 'Check out our new arrivals!',
    captionAm: 'አዲስ ምርቶቻችንን ይመልከቱ!',
    callToAction: 'Shop now',
    hashtags: ['#new', '#shop'],
  );

  setUp(() {
    remote = MockGenerationRemoteDataSource();
    repository = GenerationRepositoryImpl(remote);
  });

  test('generateText maps the domain enums to their wire values and the '
      'response DTO to a GenerationResult on success', () async {
    when(
      () => remote.generateText(
        inputText: 'New arrivals',
        inputLang: 'en',
        platform: 'instagram',
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer((_) async => responseDto);

    final result = await repository.generateText(
      inputText: 'New arrivals',
      inputLanguage: InputLanguage.en,
      platform: ContentPlatform.instagram,
      brandKitId: 'brand-kit-1',
    );

    // Result/Ok/Err have no `==` override (see core/error/result.dart) —
    // compare the unwrapped, Equatable GenerationResult rather than the
    // Result wrapper itself, same as GenerationBloc/its tests do via
    // `result.when`.
    expect(
      result.valueOrNull,
      const GenerationResult(
        captionEn: 'Check out our new arrivals!',
        captionAm: 'አዲስ ምርቶቻችንን ይመልከቱ!',
        callToAction: 'Shop now',
        hashtags: ['#new', '#shop'],
        isFallback: false,
      ),
    );
  });

  test('generateText propagates isFallback: true from the DTO', () async {
    when(
      () => remote.generateText(
        inputText: 'New arrivals',
        inputLang: 'auto',
        platform: 'telegram',
      ),
    ).thenAnswer((_) async => responseDto.copyWith(isFallback: true));

    final result = await repository.generateText(
      inputText: 'New arrivals',
      inputLanguage: InputLanguage.auto,
      platform: ContentPlatform.telegram,
    );

    expect(result.valueOrNull?.isFallback, isTrue);
  });

  test('generateText converts an ApiException into a Result.err carrying its '
      'ApiFailure', () async {
    when(
      () => remote.generateText(
        inputText: 'New arrivals',
        inputLang: 'en',
        platform: 'instagram',
      ),
    ).thenThrow(
      ApiException(
        const ApiFailure(
          type: ApiErrorType.quotaExceeded,
          message: "You've used today's generation quota. It resets soon.",
        ),
      ),
    );

    final result = await repository.generateText(
      inputText: 'New arrivals',
      inputLanguage: InputLanguage.en,
      platform: ContentPlatform.instagram,
    );

    expect(result.isErr, isTrue);
    result.when(
      ok: (_) => fail('expected an error'),
      err: (failure) {
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).type, ApiErrorType.quotaExceeded);
      },
    );
  });

  test('generateText converts an unanticipated exception into an '
      'UnexpectedFailure rather than letting it propagate', () async {
    when(
      () => remote.generateText(
        inputText: 'New arrivals',
        inputLang: 'en',
        platform: 'instagram',
      ),
    ).thenThrow(StateError('boom'));

    final result = await repository.generateText(
      inputText: 'New arrivals',
      inputLanguage: InputLanguage.en,
      platform: ContentPlatform.instagram,
    );

    expect(result.isErr, isTrue);
    expect(
      result.when(ok: (_) => null, err: (failure) => failure),
      isA<UnexpectedFailure>(),
    );
  });

  const imageResponseDto = GenerateImageResponseDto(
    assetId: 'asset-1',
    imageUrl: 'https://picsum.photos/seed/1/1080/1080',
    width: 1080,
    height: 1080,
  );

  test('generateImage maps the aspect ratio to its wire value and the '
      'response DTO to a GenerationImageResult on success', () async {
    when(
      () => remote.generateImage(
        captionEn: 'Check out our new arrivals!',
        aspectRatio: '1:1',
        brandKitId: 'brand-kit-1',
      ),
    ).thenAnswer((_) async => imageResponseDto);

    final result = await repository.generateImage(
      captionEn: 'Check out our new arrivals!',
      aspectRatio: GenerationAspectRatio.oneToOne,
      brandKitId: 'brand-kit-1',
    );

    expect(
      result.valueOrNull,
      const GenerationImageResult(
        assetId: 'asset-1',
        imageUrl: 'https://picsum.photos/seed/1/1080/1080',
        width: 1080,
        height: 1080,
      ),
    );
  });

  test('generateImage converts an ApiException into a Result.err carrying '
      'its ApiFailure', () async {
    when(
      () => remote.generateImage(
        captionEn: 'Check out our new arrivals!',
        aspectRatio: '4:5',
        brandKitId: 'brand-kit-1',
      ),
    ).thenThrow(
      ApiException(
        const ApiFailure(
          type: ApiErrorType.quotaExceeded,
          message: "You've used today's generation quota. It resets soon.",
        ),
      ),
    );

    final result = await repository.generateImage(
      captionEn: 'Check out our new arrivals!',
      aspectRatio: GenerationAspectRatio.fourToFive,
      brandKitId: 'brand-kit-1',
    );

    expect(result.isErr, isTrue);
    result.when(
      ok: (_) => fail('expected an error'),
      err: (failure) {
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).type, ApiErrorType.quotaExceeded);
      },
    );
  });

  test('generateImage converts an unanticipated exception into an '
      'UnexpectedFailure rather than letting it propagate', () async {
    when(
      () => remote.generateImage(
        captionEn: 'Check out our new arrivals!',
        aspectRatio: '1:1',
        brandKitId: 'brand-kit-1',
      ),
    ).thenThrow(StateError('boom'));

    final result = await repository.generateImage(
      captionEn: 'Check out our new arrivals!',
      aspectRatio: GenerationAspectRatio.oneToOne,
      brandKitId: 'brand-kit-1',
    );

    expect(result.isErr, isTrue);
    expect(
      result.when(ok: (_) => null, err: (failure) => failure),
      isA<UnexpectedFailure>(),
    );
  });
}
