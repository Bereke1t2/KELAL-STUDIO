import 'dart:typed_data';

import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/models/upload_asset_response_dto.dart';

/// Professional fake: realistic latency (via [FakeBackendSupport.latency])
/// and one seeded brand kit for the demo user — see
/// mobile/.claude/skills/flutter-networking-data/SKILL.md. Unlike the real
/// implementation, this fake has no id-resolution gap: it's a single
/// in-memory record, so "get my brand kit" trivially means "return the one
/// record this fake knows about."
class FakeBrandKitRemoteDataSource implements BrandKitRemoteDataSource {
  /// Brand name derived from the seeded demo account
  /// (`demo@kelalstudio.app`, see `FakeAuthRemoteDataSource`) — sensible
  /// defaults for a first-run demo, not meant to imply a real business
  /// exists by that name. Colors reuse this app's own brand primary/border
  /// swatches (`AppColors.primaryDefault`/`borderBrand`) as a tasteful
  /// pre-filled pair rather than an arbitrary placeholder; tone/contact
  /// start empty per the task's "sensible defaults" instruction.
  BrandKitDto _brandKit = BrandKitDto(
    id: 'demo-brand-kit-0001',
    brandName: 'Demo Business',
    primaryColorHex: '#855312',
    secondaryColorHex: '#C6821F',
    toneOfVoice: '',
    contactInfo: '',
    updatedAt: DateTime.now().toUtc(),
  );

  int _uploadCounter = 0;

  @override
  Future<BrandKitDto> getBrandKit() async {
    await FakeBackendSupport.latency();
    return _brandKit;
  }

  @override
  Future<BrandKitDto> updateBrandKit(BrandKitDto brandKit) async {
    await FakeBackendSupport.latency();
    return _brandKit = brandKit.copyWith(updatedAt: DateTime.now().toUtc());
  }

  @override
  Future<UploadAssetResponseDto> uploadAsset({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    await FakeBackendSupport.latency();
    _uploadCounter++;
    // Deterministic, distinguishable fake ids/refs — enough for widget/bloc
    // tests to assert on without needing a real storage backend.
    return UploadAssetResponseDto(
      assetId: 'fake-asset-$_uploadCounter',
      storageRef: 'fake://brand-logos/$_uploadCounter-$filename',
    );
  }
}
