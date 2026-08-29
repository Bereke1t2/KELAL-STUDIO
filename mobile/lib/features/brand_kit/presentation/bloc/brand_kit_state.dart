import 'package:equatable/equatable.dart';

import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';

sealed class BrandKitState extends Equatable {
  const BrandKitState();

  @override
  List<Object?> get props => const [];
}

final class BrandKitInitial extends BrandKitState {
  const BrandKitInitial();
}

final class BrandKitLoadInProgress extends BrandKitState {
  const BrandKitLoadInProgress();
}

/// The initial `getBrandKit()` call itself failed — there's no draft to
/// show yet, unlike every state below.
final class BrandKitLoadFailure extends BrandKitState {
  const BrandKitLoadFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

/// Base for every state reached once a brand kit has loaded successfully at
/// least once — always carries the current working draft so the form never
/// loses in-progress edits across a save/upload transition (e.g. a failed
/// save must not blank the fields the user just typed).
sealed class BrandKitReady extends BrandKitState {
  const BrandKitReady(this.brandKit);
  final BrandKit brandKit;

  @override
  List<Object?> get props => [brandKit];
}

final class BrandKitLoaded extends BrandKitReady {
  const BrandKitLoaded(super.brandKit);
}

final class BrandKitSaving extends BrandKitReady {
  const BrandKitSaving(super.brandKit);
}

final class BrandKitSaveFailure extends BrandKitReady {
  const BrandKitSaveFailure(super.brandKit, this.message);
  final String message;

  @override
  List<Object?> get props => [brandKit, message];
}

final class BrandKitUploadingLogo extends BrandKitReady {
  const BrandKitUploadingLogo(super.brandKit);
}

final class BrandKitLogoUploadFailure extends BrandKitReady {
  const BrandKitLogoUploadFailure(super.brandKit, this.message);
  final String message;

  @override
  List<Object?> get props => [brandKit, message];
}
