import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
// `GalPlatform` is gal's own settable test seam but isn't re-exported by
// the public `package:gal/gal.dart` barrel — this is the same "reach into
// the package's own src/ platform-interface file" approach the package's
// own wiki documents for testing, not a workaround.
import 'package:gal/src/gal_platform_interface.dart';
import 'package:kelal_studio/features/export/data/datasources/gallery_datasource.dart';

/// Fake `GalPlatform` — `gal`'s own settable test seam (`GalPlatform.instance`,
/// a plain settable static, not gated behind a `PlatformInterface` token the
/// way `share_plus`'s is) — see `GalGalleryDataSource`'s doc comment for why
/// this is preferred over `MethodChannel` mocking.
base class _FakeGalPlatform extends GalPlatform {
  _FakeGalPlatform({
    this.hasAccessResult = true,
    this.requestAccessResult = true,
    this.putImageBytesError,
  });

  final bool hasAccessResult;
  final bool requestAccessResult;
  final GalException? putImageBytesError;

  Uint8List? savedBytes;
  String? savedName;

  @override
  Future<bool> hasAccess({bool toAlbum = false}) async => hasAccessResult;

  @override
  Future<bool> requestAccess({bool toAlbum = false}) async =>
      requestAccessResult;

  @override
  Future<void> putImageBytes(
    Uint8List bytes, {
    required String name,
    String? album,
  }) async {
    if (putImageBytesError != null) throw putImageBytesError!;
    savedBytes = bytes;
    savedName = name;
  }
}

void main() {
  late GalPlatform originalPlatform;

  setUp(() {
    originalPlatform = GalPlatform.instance;
  });

  tearDown(() {
    GalPlatform.instance = originalPlatform;
  });

  group('GalGalleryDataSource.saveImageBytes', () {
    test('writes the bytes directly when access is already granted', () async {
      final fake = _FakeGalPlatform();
      GalPlatform.instance = fake;
      const dataSource = GalGalleryDataSource();
      final bytes = Uint8List.fromList([1, 2, 3]);

      await dataSource.saveImageBytes(bytes);

      expect(fake.savedBytes, bytes);
    });

    test('requests access first when not already granted, then writes once '
        'granted', () async {
      final fake = _FakeGalPlatform(hasAccessResult: false);
      GalPlatform.instance = fake;
      const dataSource = GalGalleryDataSource();
      final bytes = Uint8List.fromList([4, 5, 6]);

      await dataSource.saveImageBytes(bytes);

      expect(fake.savedBytes, bytes);
    });

    test('throws GalleryAccessDeniedException, without ever attempting the '
        'write, when the permission request is denied', () async {
      final fake = _FakeGalPlatform(
        hasAccessResult: false,
        requestAccessResult: false,
      );
      GalPlatform.instance = fake;
      const dataSource = GalGalleryDataSource();

      await expectLater(
        () => dataSource.saveImageBytes(Uint8List(0)),
        throwsA(isA<GalleryAccessDeniedException>()),
      );
      expect(fake.savedBytes, isNull);
    });

    test('lets a GalException thrown by the write itself propagate unchanged '
        '(e.g. notEnoughSpace — device-storage-full is a required edge case '
        'per the review checklist)', () async {
      final exception = GalException(
        type: GalExceptionType.notEnoughSpace,
        platformException: PlatformException(code: 'NOT_ENOUGH_SPACE'),
        stackTrace: StackTrace.empty,
      );
      final fake = _FakeGalPlatform(putImageBytesError: exception);
      GalPlatform.instance = fake;
      const dataSource = GalGalleryDataSource();

      await expectLater(
        () => dataSource.saveImageBytes(Uint8List(0)),
        throwsA(same(exception)),
      );
    });
  });
}
