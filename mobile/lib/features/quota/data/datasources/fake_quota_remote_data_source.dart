import 'package:kelal_studio/core/network/fake_backend_support.dart';
import 'package:kelal_studio/features/quota/data/datasources/quota_remote_data_source.dart';
import 'package:kelal_studio/features/quota/data/models/quota_dto.dart';

/// Professional fake: realistic latency (via [FakeBackendSupport.latency])
/// and an in-memory quota state for the demo user — see
/// mobile/.claude/skills/flutter-networking-data/SKILL.md.
///
/// **The limits below are a placeholder, not a product decision.** PRD
/// §2.3 explicitly lists per-user/system numeric quota limits as an *Open*
/// question — no target is set anywhere in the PRD or in
/// mobile/api_contract/openapi.yaml's `Quota` schema (it only defines the
/// shape, not values). `10` text calls/day and `5` image calls/day below
/// are a clearly-flagged, arbitrary stand-in so the mock backend can return
/// *something* shaped like a real quota response; they must not be read as
/// an authoritative number by anyone building against this fake. Whoever
/// resolves OQ (PRD §2.3) should replace these two constants (and the real
/// backend will supply the real number once it exists).
///
/// **Judgment call on exhaustion-testing (flagged, not silently decided)**:
/// the task allowed either (a) a small in-memory counter the fake
/// increments on repeated calls, or (b) leaning on bloc-level tests with a
/// mocked repository instead. This class does (a) — [getQuota] increments
/// both counters (clamped at their limits) on every call — because it's a
/// few lines and it means a developer manually driving the app (or an
/// integration test) can reach the near-limit/exhausted `QuotaBadge`
/// states just by triggering a few refreshes, without needing a mocked
/// repository. The Bloc/widget *unit* tests still use a mocked
/// `GetQuotaUseCase`/repository directly (see
/// `test/features/quota/presentation/bloc/quota_bloc_test.dart`) rather
/// than depending on this fake's counter behavior — this fake's counter is
/// for manual/exploratory use, not test determinism.
class FakeQuotaRemoteDataSource implements QuotaRemoteDataSource {
  // PLACEHOLDER pending PRD §2.3 — see class doc comment.
  static const int _textCallsLimit = 10;
  static const int _imageCallsLimit = 5;

  // Seeded partially-used, not maxed out, per the task's "plausible
  // default" instruction — the first call already reports some usage
  // rather than a pristine 0/0 state, since a brand-new-session 0-used
  // badge is a less useful default to develop against.
  int _textCallsUsed = 3;
  int _imageCallsUsed = 1;

  @override
  Future<QuotaDto> getQuota() async {
    await FakeBackendSupport.latency();

    _textCallsUsed = (_textCallsUsed + 1).clamp(0, _textCallsLimit);
    _imageCallsUsed = (_imageCallsUsed + 1).clamp(0, _imageCallsLimit);

    return QuotaDto(
      textCallsUsed: _textCallsUsed,
      textCallsLimit: _textCallsLimit,
      imageCallsUsed: _imageCallsUsed,
      imageCallsLimit: _imageCallsLimit,
      // Always a fixed distance out, not wall-clock-midnight — simplest
      // deterministic-enough placeholder for a mock; a real backend
      // decides the actual reset cadence/timezone.
      resetsAt: DateTime.now().toUtc().add(const Duration(hours: 6)),
    );
  }
}
