import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelal_studio/features/export/data/datasources/share_datasource.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// Fake `SharePlatform` — `share_plus`'s own `@visibleForTesting`
/// `SharePlus.custom(...)` test seam (see `SharePlusDataSource`'s doc
/// comment). Overrides `share` directly rather than relying on the base
/// class's default implementation, which would otherwise recurse back into
/// `SharePlatform.instance` instead of exercising this fake.
class _FakeSharePlatform extends SharePlatform {
  _FakeSharePlatform({this.error});

  final Exception? error;
  ShareParams? capturedParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    if (error != null) throw error!;
    capturedParams = params;
    return const ShareResult('com.example.app', ShareResultStatus.success);
  }
}

void main() {
  tearDown(() {
    // Restore the production seam so a leaked fake from one test can't
    // bleed into another test file sharing the same isolate.
    SharePlusDataSource.instance = SharePlus.instance;
  });

  group('SharePlusDataSource.shareImageBytes', () {
    test('invokes SharePlus with the PNG bytes attached as a file and the '
        'caption text passed through as the share text', () async {
      final fake = _FakeSharePlatform();
      SharePlusDataSource.instance = SharePlus.custom(fake);
      const dataSource = SharePlusDataSource();
      final bytes = Uint8List.fromList([9, 9, 9]);

      await dataSource.shareImageBytes(bytes: bytes, text: 'Check this out');

      final params = fake.capturedParams;
      expect(params, isNotNull);
      expect(params!.files, hasLength(1));
      expect(params.files!.single.mimeType, 'image/png');
      expect(await params.files!.single.readAsBytes(), bytes);
      expect(params.text, 'Check this out');
    });

    test('passes null text through when no caption is provided', () async {
      final fake = _FakeSharePlatform();
      SharePlusDataSource.instance = SharePlus.custom(fake);
      const dataSource = SharePlusDataSource();

      await dataSource.shareImageBytes(bytes: Uint8List.fromList([1]));

      expect(fake.capturedParams!.text, isNull);
    });

    test('lets an exception thrown by the platform share() call propagate '
        'unchanged — ExportRepositoryImpl is the layer that maps it', () async {
      final fake = _FakeSharePlatform(error: Exception('boom'));
      SharePlusDataSource.instance = SharePlus.custom(fake);
      const dataSource = SharePlusDataSource();

      await expectLater(
        () => dataSource.shareImageBytes(bytes: Uint8List(0)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
