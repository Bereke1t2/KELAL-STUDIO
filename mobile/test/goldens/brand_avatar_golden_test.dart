import 'package:flutter/material.dart';
import 'package:kelal_studio/core/widgets/brand_avatar.dart';

import 'golden_helpers.dart';

/// Golden coverage for [BrandAvatar] — Figma `Components / Avatar & Logo
/// Tile`, node `48:2`: "Has Logo" (`48:6`), "Initial Fallback" (`48:9`),
/// "Uploading" (`48:13`), "Error" (`48:18`).
void main() {
  goldenThemeTest(
    'Brand avatar renders every Figma-documented status',
    fileName: 'brand_avatar',
    surfaceSize: const Size(160, 190),
    variants: {
      'has logo': (context) => const BrandAvatar(
        status: BrandAvatarStatus.hasLogo,
        caption: 'Uploaded',
        logo: ColoredBox(color: Colors.brown),
      ),
      'initial fallback - english': (context) => const BrandAvatar(
        status: BrandAvatarStatus.initialFallback,
        caption: 'No logo yet',
        initial: 'K',
      ),
      'initial fallback - amharic': (context) => const BrandAvatar(
        status: BrandAvatarStatus.initialFallback,
        caption: 'ምንም አርማ የለም',
        initial: 'ቀ',
      ),
      'uploading': (context) => const BrandAvatar(
        status: BrandAvatarStatus.uploading,
        caption: 'Uploading…',
        uploadProgress: 0.65,
      ),
      'error': (context) => const BrandAvatar(
        status: BrandAvatarStatus.error,
        caption: 'Logo must be at least 200×200px',
      ),
    },
  );
}
