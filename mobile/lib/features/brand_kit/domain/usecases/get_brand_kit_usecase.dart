import 'package:injectable/injectable.dart';

import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/brand_kit/domain/entities/brand_kit.dart';
import 'package:kelal_studio/features/brand_kit/domain/repositories/brand_kit_repository.dart';

/// One class per use case, single `call()` method — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md. Blocs call use
/// cases, never repositories directly.
@injectable
class GetBrandKitUseCase {
  GetBrandKitUseCase(this._repository);

  final BrandKitRepository _repository;

  Future<Result<Failure, BrandKit>> call() => _repository.getBrandKit();
}
