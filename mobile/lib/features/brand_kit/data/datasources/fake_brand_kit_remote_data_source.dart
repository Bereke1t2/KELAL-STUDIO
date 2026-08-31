import 'dart:typed_data';

import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/brand_kit/data/datasources/brand_kit_remote_data_source.dart';
import 'package:kelal_studio/features/brand_kit/data/models/asset_dto.dart';
import 'package:kelal_studio/features/brand_kit/data/models/brand_kit_dto.dart';

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
  Future<AssetDto> uploadAsset({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    await FakeBackendSupport.latency();
    _uploadCounter++;
    // Deterministic, distinguishable fake id — enough for widget/bloc
    // tests to assert on without needing a real storage backend. Width/
    // height are placeholders (this fake never actually decodes [bytes]);
    // nothing in this codebase reads them from an upload response today.
    return AssetDto(
      id: 'fake-asset-$_uploadCounter',
      width: 512,
      height: 512,
      mimeType: mimeType,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
