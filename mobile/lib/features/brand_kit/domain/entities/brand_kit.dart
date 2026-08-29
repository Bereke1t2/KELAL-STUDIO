import 'package:equatable/equatable.dart';

/// Pure-Dart domain entity — no Flutter, no json, no dio imports here (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule). [data/models/brand_kit_dto.dart] maps onto this; this is what use
/// cases and presentation code actually depend on.
///
/// Mirrors `BrandKit` in mobile/api_contract/openapi.yaml. That schema
/// doesn't mark any field `required` (unlike `AuthTokens`/`User`), but a
/// brand kit is always fetched/created as a complete record in practice —
/// the fake data source seeds one fully-populated kit per user and a real
/// backend would do the same (tone/contact default to empty strings rather
/// than being genuinely absent) — so every field here is non-nullable
/// except [logoAssetId], which is genuinely optional (no logo uploaded
/// yet).
class BrandKit extends Equatable {
  const BrandKit({
    required this.id,
    required this.brandName,
    required this.logoAssetId,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    required this.toneOfVoice,
    required this.contactInfo,
    required this.updatedAt,
  });

  final String id;
  final String brandName;

  /// Null until a logo has been uploaded and associated via [updatedAt]'s
  /// owning `updateBrandKit` call — uploading alone (see
  /// `UploadBrandLogoUseCase`) doesn't set this; the caller must still save
  /// the brand kit with the new id for it to persist server-side.
  final String? logoAssetId;
  final String primaryColorHex;
  final String secondaryColorHex;
  final String toneOfVoice;
  final String contactInfo;
  final DateTime updatedAt;

  /// Convenience copy for building the next edit/save draft. [updatedAt] is
  /// deliberately never overridable here — it's server-assigned and only
  /// ever changes via a fresh [BrandKit] built from a repository response.
  BrandKit copyWith({
    String? brandName,
    String? logoAssetId,
    String? primaryColorHex,
    String? secondaryColorHex,
    String? toneOfVoice,
    String? contactInfo,
  }) {
    return BrandKit(
      id: id,
      brandName: brandName ?? this.brandName,
      logoAssetId: logoAssetId ?? this.logoAssetId,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      toneOfVoice: toneOfVoice ?? this.toneOfVoice,
      contactInfo: contactInfo ?? this.contactInfo,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    brandName,
    logoAssetId,
    primaryColorHex,
    secondaryColorHex,
    toneOfVoice,
    contactInfo,
    updatedAt,
  ];
}
