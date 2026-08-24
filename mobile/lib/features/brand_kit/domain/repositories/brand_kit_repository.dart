import 'dart:typed_data';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';

/// Interface only — no `dio`, no `retrofit` import here. The concrete
/// implementation (`data/repositories/brand_kit_repository_impl.dart`)
/// picks a real or fake data source at construction time; nothing above
/// this interface knows or cares which. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
///
/// `dart:typed_data`'s [Uint8List] is a core Dart type (no Flutter/image
/// package involved), so it's safe to use here per the domain-purity rule —
/// this keeps `domain/` from ever importing `image_picker`'s `XFile` or
/// `dart:io`'s `File`.
abstract class BrandKitRepository {
  /// Fetches the signed-in user's brand kit. See the known contract-gap
  /// flag on `RealBrandKitRemoteDataSource` — the *fake* data source always
  /// resolves this against one seeded kit; the real one is flagged as
  /// non-functional today for a documented reason, not a silent gap.
  Future<Result<Failure, BrandKit>> getBrandKit();

  /// Persists the given [brandKit] (including any pending
  /// [BrandKit.logoAssetId] change from a prior [uploadLogo] call —
  /// uploading alone doesn't persist the association, only this does) and
  /// returns the server-confirmed copy (fresh [BrandKit.updatedAt]).
  Future<Result<Failure, BrandKit>> updateBrandKit(BrandKit brandKit);

  /// Uploads raw image bytes and returns the new asset's id. Deliberately
  /// takes primitives ([bytes]/[filename]/[mimeType]) rather than an
  /// `image_picker` `XFile` — that type must never leak into `domain/`.
  /// Does **not** associate the asset with the brand kit by itself; the
  /// caller must still call [updateBrandKit] with the returned id set on
  /// [BrandKit.logoAssetId] for it to persist.
  Future<Result<Failure, String>> uploadLogo({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  });
}
