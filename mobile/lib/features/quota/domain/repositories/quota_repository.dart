import 'package:kelal_studio/core/error/result.dart';
import 'package:kelal_studio/features/quota/domain/entities/quota.dart';

/// Interface only — no `dio`, no `retrofit` import here. The concrete
/// implementation (`data/repositories/quota_repository_impl.dart`) picks a
/// real or fake data source at construction time; nothing above this
/// interface knows or cares which. See
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
abstract class QuotaRepository {
  /// Fetches the signed-in user's current quota (`GET /quota/me`).
  Future<Result<Failure, Quota>> getQuota();
}
