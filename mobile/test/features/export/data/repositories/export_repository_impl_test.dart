import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/export/data/datasources/gallery_datasource.dart';
import 'package:kelal_studio/features/export/data/datasources/share_datasource.dart';
import 'package:kelal_studio/features/export/data/repositories/export_repository_impl.dart';
import 'package:kelal_studio/features/export/domain/entities/export_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockGalleryDataSource extends Mock implements GalleryDataSource {}

class MockShareDataSource extends Mock implements ShareDataSource {}

void main() {
  late MockGalleryDataSource galleryDataSource;
  late MockShareDataSource shareDataSource;
  late ExportRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    galleryDataSource = MockGalleryDataSource();
    shareDataSource = MockShareDataSource();
    repository = ExportRepositoryImpl(galleryDataSource, shareDataSource);
  });

  group('saveToGallery', () {
    test('returns Ok when the data source writes successfully', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(
        () => galleryDataSource.saveImageBytes(bytes),
      ).thenAnswer((_) async {});

      final result = await repository.saveToGallery(bytes);

      expect(result.isOk, isTrue);
    });

    test(
      'maps GalleryAccessDeniedException to galleryPermissionDenied',
      () async {
        final bytes = Uint8List(0);
        when(
          () => galleryDataSource.saveImageBytes(bytes),
        ).thenThrow(const GalleryAccessDeniedException());

        final result = await repository.saveToGallery(bytes);

        expect(result.isErr, isTrue);
        expect(
          (result as Err<ExportFailure, void>).failure.type,
          ExportFailureType.galleryPermissionDenied,
        );
      },
    );

    test('maps a GalException(accessDenied) thrown mid-write to '
        'galleryPermissionDenied too (permission revoked between the '
        'pre-check and the write itself)', () async {
      final bytes = Uint8List(0);
      when(() => galleryDataSource.saveImageBytes(bytes)).thenThrow(
        GalException(
          type: GalExceptionType.accessDenied,
          platformException: PlatformException(code: 'ACCESS_DENIED'),
          stackTrace: StackTrace.empty,
        ),
      );

      final result = await repository.saveToGallery(bytes);

      expect(
        (result as Err<ExportFailure, void>).failure.type,
        ExportFailureType.galleryPermissionDenied,
      );
    });

    test('maps GalException(notEnoughSpace) to galleryWriteFailed — the '
        'device-storage-full edge case', () async {
      final bytes = Uint8List(0);
      when(() => galleryDataSource.saveImageBytes(bytes)).thenThrow(
        GalException(
          type: GalExceptionType.notEnoughSpace,
          platformException: PlatformException(code: 'NOT_ENOUGH_SPACE'),
          stackTrace: StackTrace.empty,
        ),
      );

      final result = await repository.saveToGallery(bytes);

      expect(
        (result as Err<ExportFailure, void>).failure.type,
        ExportFailureType.galleryWriteFailed,
      );
    });

    test(
      'maps GalException(notSupportedFormat) to galleryWriteFailed',
      () async {
        final bytes = Uint8List(0);
        when(() => galleryDataSource.saveImageBytes(bytes)).thenThrow(
          GalException(
            type: GalExceptionType.notSupportedFormat,
            platformException: PlatformException(code: 'NOT_SUPPORTED_FORMAT'),
            stackTrace: StackTrace.empty,
          ),
        );

        final result = await repository.saveToGallery(bytes);

        expect(
          (result as Err<ExportFailure, void>).failure.type,
          ExportFailureType.galleryWriteFailed,
        );
      },
    );

    test('maps GalException(unexpected) to unknown', () async {
      final bytes = Uint8List(0);
      when(() => galleryDataSource.saveImageBytes(bytes)).thenThrow(
        GalException(
          type: GalExceptionType.unexpected,
          platformException: PlatformException(code: 'UNEXPECTED'),
          stackTrace: StackTrace.empty,
        ),
      );

      final result = await repository.saveToGallery(bytes);

      expect(
        (result as Err<ExportFailure, void>).failure.type,
        ExportFailureType.unknown,
      );
    });

    test('maps a non-GalException throw (e.g. a misconfigured platform '
        'channel) to unknown rather than letting it escape unmapped', () async {
      final bytes = Uint8List(0);
      when(
        () => galleryDataSource.saveImageBytes(bytes),
      ).thenThrow(StateError('unexpected'));

      final result = await repository.saveToGallery(bytes);

      expect(
        (result as Err<ExportFailure, void>).failure.type,
        ExportFailureType.unknown,
      );
    });
  });

  group('shareImage', () {
    test('returns Ok once the share sheet has been invoked', () async {
      final bytes = Uint8List.fromList([4, 5, 6]);
      when(
        () => shareDataSource.shareImageBytes(bytes: bytes, text: 'caption'),
      ).thenAnswer((_) async {});

      final result = await repository.shareImage(
        pngBytes: bytes,
        text: 'caption',
      );

      expect(result.isOk, isTrue);
    });

    test(
      'maps any exception from the share data source to shareFailed',
      () async {
        final bytes = Uint8List(0);
        when(
          () => shareDataSource.shareImageBytes(
            bytes: bytes,
            text: any(named: 'text'),
          ),
        ).thenThrow(Exception('share failed'));

        final result = await repository.shareImage(pngBytes: bytes);

        expect(
          (result as Err<ExportFailure, void>).failure.type,
          ExportFailureType.shareFailed,
        );
      },
    );
  });
}
