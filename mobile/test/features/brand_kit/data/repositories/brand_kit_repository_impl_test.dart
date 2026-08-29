import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Canvas, Color, Paint, Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/models/upload_asset_response_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/repositories/brand_kit_repository_impl.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/logo_validation_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockBrandKitRemoteDataSource extends Mock
    implements BrandKitRemoteDataSource {}

/// Same technique as `logo_upload_hardener_test.dart` — a real,
/// `ui.instantiateImageCodec`-decodable PNG rendered at runtime, needed
/// because `BrandKitRepositoryImpl.uploadLogo` runs its bytes through the
/// real (non-mocked) `LogoUploadHardener` before ever reaching the data
/// source — see that repository's doc comment on why the hardener is
/// instantiated directly rather than dependency-injected.
Future<Uint8List> _validPngBytes({int width = 8, int height = 8}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late MockBrandKitRemoteDataSource remote;
  late BrandKitRepositoryImpl repository;

  setUp(() {
    remote = MockBrandKitRemoteDataSource();
    repository = BrandKitRepositoryImpl(remote);
  });

  final dto = BrandKitDto(
    id: 'brand-kit-1',
    brandName: 'Demo Business',
    primaryColorHex: '#855312',
    secondaryColorHex: '#C6821F',
    toneOfVoice: '',
    contactInfo: '',
    updatedAt: DateTime.utc(2026),
  );

  final entity = BrandKit(
    id: 'brand-kit-1',
    brandName: 'Demo Business',
    logoAssetId: null,
    primaryColorHex: '#855312',
    secondaryColorHex: '#C6821F',
    toneOfVoice: '',
    contactInfo: '',
    updatedAt: DateTime.utc(2026),
  );

  group('getBrandKit', () {
    test('maps a successful DTO response to the domain entity', () async {
      when(remote.getBrandKit).thenAnswer((_) async => dto);

      final result = await repository.getBrandKit();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, entity);
    });

    test('maps an ApiException to a Result.err', () async {
      when(remote.getBrandKit).thenThrow(
        ApiException(
          const ApiFailure(
            type: ApiErrorType.network,
            message: 'No connection. Check your network and try again.',
          ),
        ),
      );

      final result = await repository.getBrandKit();

      expect(result.isErr, isTrue);
    });

    test('maps an unanticipated exception to UnexpectedFailure rather than '
        'propagating it', () async {
      when(remote.getBrandKit).thenThrow(StateError('boom'));

      final result = await repository.getBrandKit();

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected an error'),
        err: (failure) => expect(failure, isA<UnexpectedFailure>()),
      );
    });
  });

  group('updateBrandKit', () {
    test(
      'sends the DTO form of the given entity and maps the response',
      () async {
        when(() => remote.updateBrandKit(dto)).thenAnswer((_) async => dto);

        final result = await repository.updateBrandKit(entity);

        expect(result.isOk, isTrue);
        expect(result.valueOrNull, entity);
        verify(() => remote.updateBrandKit(dto)).called(1);
      },
    );

    test('maps an ApiException to a Result.err', () async {
      when(() => remote.updateBrandKit(dto)).thenThrow(
        ApiException(
          const ApiFailure(
            type: ApiErrorType.validationError,
            message: 'Please check your input and try again.',
          ),
        ),
      );

      final result = await repository.updateBrandKit(entity);

      expect(result.isErr, isTrue);
    });
  });

  group('uploadLogo', () {
    test('a file rejected by the client-side hardening check never reaches '
        'the data source, and surfaces a LogoValidationFailure', () async {
      final unreadable = Uint8List.fromList([1, 2, 3]);

      final result = await repository.uploadLogo(
        bytes: unreadable,
        filename: 'logo.png',
        mimeType: 'image/png',
      );

      expect(result.isErr, isTrue);
      result.when(
        ok: (_) => fail('expected a LogoValidationFailure'),
        err: (failure) => expect(failure, isA<LogoValidationFailure>()),
      );
      verifyNever(
        () => remote.uploadAsset(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          mimeType: any(named: 'mimeType'),
        ),
      );
    });

    test('a file that passes hardening is uploaded as re-encoded PNG bytes '
        'under a .png filename, regardless of the original filename/mime '
        'type, and returns the new asset id', () async {
      final picked = await _validPngBytes();
      when(
        () => remote.uploadAsset(
          bytes: any(named: 'bytes'),
          filename: any(named: 'filename'),
          mimeType: any(named: 'mimeType'),
        ),
      ).thenAnswer(
        (_) async => const UploadAssetResponseDto(
          assetId: 'asset-1',
          storageRef: 'fake://brand-logos/1',
        ),
      );

      final result = await repository.uploadLogo(
        bytes: picked,
        filename: 'photo.jpg',
        mimeType: 'image/jpeg',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 'asset-1');
      final captured = verify(
        () => remote.uploadAsset(
          bytes: captureAny(named: 'bytes'),
          filename: captureAny(named: 'filename'),
          mimeType: captureAny(named: 'mimeType'),
        ),
      ).captured;
      expect(captured[1], 'photo.png');
      expect(captured[2], 'image/png');
    });
  });
}
