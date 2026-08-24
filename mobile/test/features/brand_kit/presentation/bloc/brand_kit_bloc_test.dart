import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/logo_validation_failure.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/get_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/update_brand_kit_usecase.dart';
import 'package:kelal_studio/features/brand_kit/domain/usecases/upload_brand_logo_usecase.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_bloc.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_event.dart';
import 'package:kelal_studio/features/brand_kit/presentation/bloc/brand_kit_state.dart';
import 'package:mocktail/mocktail.dart';

class MockGetBrandKitUseCase extends Mock implements GetBrandKitUseCase {}

class MockUpdateBrandKitUseCase extends Mock implements UpdateBrandKitUseCase {}

class MockUploadBrandLogoUseCase extends Mock
    implements UploadBrandLogoUseCase {}

void main() {
  late MockGetBrandKitUseCase getBrandKitUseCase;
  late MockUpdateBrandKitUseCase updateBrandKitUseCase;
  late MockUploadBrandLogoUseCase uploadBrandLogoUseCase;

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

  final savedBrandKit = brandKit.copyWith(brandName: 'Renamed Business');

  setUpAll(() {
    registerFallbackValue(brandKit);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    getBrandKitUseCase = MockGetBrandKitUseCase();
    updateBrandKitUseCase = MockUpdateBrandKitUseCase();
    uploadBrandLogoUseCase = MockUploadBrandLogoUseCase();
  });

  BrandKitBloc buildBloc() => BrandKitBloc(
    getBrandKitUseCase,
    updateBrandKitUseCase,
    uploadBrandLogoUseCase,
  );

  group('BrandKitLoadRequested', () {
    blocTest<BrandKitBloc, BrandKitState>(
      'emits [LoadInProgress, Loaded] on a successful load',
      setUp: () {
        when(
          getBrandKitUseCase.call,
        ).thenAnswer((_) async => Result.ok(brandKit));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const BrandKitLoadRequested()),
      expect: () => [const BrandKitLoadInProgress(), BrandKitLoaded(brandKit)],
    );

    blocTest<BrandKitBloc, BrandKitState>(
      'emits [LoadInProgress, LoadFailure] when the load fails',
      setUp: () {
        when(getBrandKitUseCase.call).thenAnswer(
          (_) async => const Result.err(
            ApiFailure(
              type: ApiErrorType.network,
              message: 'No connection. Check your network and try again.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const BrandKitLoadRequested()),
      expect: () => [
        const BrandKitLoadInProgress(),
        const BrandKitLoadFailure(
          'No connection. Check your network and try again.',
        ),
      ],
    );
  });

  group('BrandKitSaveRequested', () {
    blocTest<BrandKitBloc, BrandKitState>(
      'emits [Saving, Loaded] with the server-confirmed copy on a '
      'successful save',
      setUp: () {
        when(
          () => updateBrandKitUseCase(savedBrandKit),
        ).thenAnswer((_) async => Result.ok(savedBrandKit));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(BrandKitSaveRequested(savedBrandKit)),
      expect: () => [
        BrandKitSaving(savedBrandKit),
        BrandKitLoaded(savedBrandKit),
      ],
    );

    blocTest<BrandKitBloc, BrandKitState>(
      'emits [Saving, SaveFailure] carrying the attempted draft when the '
      'save fails',
      setUp: () {
        when(() => updateBrandKitUseCase(savedBrandKit)).thenAnswer(
          (_) async => const Result.err(
            ApiFailure(
              type: ApiErrorType.validationError,
              message: 'Please check your input and try again.',
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(BrandKitSaveRequested(savedBrandKit)),
      expect: () => [
        BrandKitSaving(savedBrandKit),
        BrandKitSaveFailure(
          savedBrandKit,
          'Please check your input and try again.',
        ),
      ],
    );

    blocTest<BrandKitBloc, BrandKitState>(
      'droppable transformer: a second save fired while the first is '
      'still in flight is dropped, not queued or run concurrently — the '
      'structural fix for a double-tap on the Save button',
      setUp: () {
        when(() => updateBrandKitUseCase(savedBrandKit)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return Result.ok(savedBrandKit);
        });
      },
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(BrandKitSaveRequested(savedBrandKit))
          ..add(BrandKitSaveRequested(savedBrandKit));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        BrandKitSaving(savedBrandKit),
        BrandKitLoaded(savedBrandKit),
      ],
      verify: (_) {
        // Exactly one save reached the use case, not two.
        verify(() => updateBrandKitUseCase(savedBrandKit)).called(1);
      },
    );
  });

  group('BrandKitLogoUploadRequested', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    blocTest<BrandKitBloc, BrandKitState>(
      'does nothing if dispatched before any brand kit has loaded',
      build: buildBloc,
      act: (bloc) => bloc.add(
        BrandKitLogoUploadRequested(
          bytes: bytes,
          filename: 'logo.png',
          mimeType: 'image/png',
        ),
      ),
      expect: () => <BrandKitState>[],
      verify: (_) {
        verifyNever(
          () => uploadBrandLogoUseCase(
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
            mimeType: any(named: 'mimeType'),
          ),
        );
      },
    );

    blocTest<BrandKitBloc, BrandKitState>(
      'emits [UploadingLogo, Loaded] with the new logoAssetId merged onto '
      'the current draft on a successful upload — the association is not '
      'yet persisted server-side (that only happens on the next Save)',
      seed: () => BrandKitLoaded(brandKit),
      setUp: () {
        when(
          () => uploadBrandLogoUseCase(
            bytes: bytes,
            filename: 'logo.png',
            mimeType: 'image/png',
          ),
        ).thenAnswer((_) async => const Result.ok('asset-99'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        BrandKitLogoUploadRequested(
          bytes: bytes,
          filename: 'logo.png',
          mimeType: 'image/png',
        ),
      ),
      expect: () => [
        BrandKitUploadingLogo(brandKit),
        BrandKitLoaded(brandKit.copyWith(logoAssetId: 'asset-99')),
      ],
    );

    blocTest<BrandKitBloc, BrandKitState>(
      'emits [UploadingLogo, LogoUploadFailure] carrying the unchanged '
      'draft when the upload fails',
      seed: () => BrandKitLoaded(brandKit),
      setUp: () {
        when(
          () => uploadBrandLogoUseCase(
            bytes: bytes,
            filename: 'logo.png',
            mimeType: 'image/png',
          ),
        ).thenAnswer(
          (_) async => const Result.err(
            LogoValidationFailure(
              "We couldn't read that image. Please choose a different file.",
            ),
          ),
        );
      },
      build: buildBloc,
      act: (bloc) => bloc.add(
        BrandKitLogoUploadRequested(
          bytes: bytes,
          filename: 'logo.png',
          mimeType: 'image/png',
        ),
      ),
      expect: () => [
        BrandKitUploadingLogo(brandKit),
        BrandKitLogoUploadFailure(
          brandKit,
          "We couldn't read that image. Please choose a different file.",
        ),
      ],
    );
  });
}
