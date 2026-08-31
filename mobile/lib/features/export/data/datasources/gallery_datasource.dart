import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:injectable/injectable.dart';

/// Thrown by [GalGalleryDataSource] when [Gal.requestAccess] returns
/// `false` after [Gal.hasAccess] was already `false` — a deliberate,
/// lightweight signal distinct from [GalException] (which `Gal.putImageBytes`
/// itself throws for `accessDenied`/`notEnoughSpace`/etc.) so the
/// pre-flight "ask, then bail if denied" path documented on
/// [GalGalleryDataSource.saveImageBytes] doesn't need to fabricate a fake
/// [GalException] (that type requires a real `PlatformException` +
/// `StackTrace` to construct, which there isn't one of here — nothing
/// native was actually called).
class GalleryAccessDeniedException implements Exception {
  const GalleryAccessDeniedException();
}

/// Data-source-layer seam over `gal` — kept as a thin interface (rather
/// than calling `Gal.*` directly from `ExportRepositoryImpl`) purely so
/// `features/export`'s repository/bloc tests can mock at this boundary
/// with `mocktail`, same "mock at the interface boundary" convention
/// `flutter-testing`/`flutter-architecture` establish elsewhere. The
/// concrete [GalGalleryDataSource] itself is tested separately by swapping
/// `GalPlatform.instance` (a settable static the `gal` package itself
/// exposes as its own test seam — see `gal_datasource_test.dart`), not
/// `MethodChannel` mocking.
abstract class GalleryDataSource {
  /// Writes [bytes] as a PNG to the device gallery, requesting permission
  /// first if needed.
  Future<void> saveImageBytes(Uint8List bytes);
}

/// PRD §6.11: exported graphics save into the device's own photo gallery,
/// not app-private storage. `gal` handles its own runtime permission
/// requesting internally (no `permission_handler` dependency needed — see
/// this branch's task notes); this class only sequences the
/// check-then-request-then-write flow the task calls for explicitly,
/// rather than relying solely on `Gal.putImageBytes`'s own internal
/// [GalException] on an unpermitted write (defense in depth: the pre-check
/// lets `ExportBloc` surface a permission-specific message before ever
/// attempting the write, not just after it fails).
@Injectable(as: GalleryDataSource)
class GalGalleryDataSource implements GalleryDataSource {
  const GalGalleryDataSource();

  /// File name gal saves under (no extension — see [Gal.putImageBytes]'s
  /// doc comment). Not user-visible; PRD doesn't specify a naming
  /// convention for gallery-saved exports.
  static const _exportFileName = 'kelal_studio_export';

  @override
  Future<void> saveImageBytes(Uint8List bytes) async {
    if (!await Gal.hasAccess()) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        throw const GalleryAccessDeniedException();
      }
    }
    // Can still throw GalException here (e.g. notEnoughSpace, or access
    // revoked in the gap between the check above and this call) —
    // ExportRepositoryImpl catches both this and GalleryAccessDeniedException.
    await Gal.putImageBytes(bytes, name: _exportFileName);
  }
}
