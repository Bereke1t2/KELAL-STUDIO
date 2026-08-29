import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';

sealed class BrandKitEvent extends Equatable {
  const BrandKitEvent();
}

/// Dispatched once when `BrandKitPage` mounts.
final class BrandKitLoadRequested extends BrandKitEvent {
  const BrandKitLoadRequested();

  @override
  List<Object?> get props => const [];
}

/// Carries the fully-assembled draft (form fields + any pending
/// [BrandKit.logoAssetId] from a prior upload) — mirrors `RegisterPage`'s
/// pattern of only dispatching on submit, not per-keystroke.
final class BrandKitSaveRequested extends BrandKitEvent {
  const BrandKitSaveRequested(this.brandKit);
  final BrandKit brandKit;

  @override
  List<Object?> get props => [brandKit];
}

/// Raw bytes from `image_picker`, already read off the picked `XFile` by
/// the page (never the `XFile` itself — see `BrandKitRepository`'s
/// domain-purity doc comment for why).
final class BrandKitLogoUploadRequested extends BrandKitEvent {
  const BrandKitLogoUploadRequested({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;

  @override
  List<Object?> get props => [bytes, filename, mimeType];
}
