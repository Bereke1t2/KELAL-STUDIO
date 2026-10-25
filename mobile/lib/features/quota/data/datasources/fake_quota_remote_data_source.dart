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
/// **`getQuota()` no longer increments on every call — this is a fix, not
/// the original design.** The previous version incremented both counters
/// on every `getQuota()` read (i.e. every time `QuotaStatusBadge` mounted,
/// which happens on every visit to `/compose`), specifically so a
/// developer manually driving the app could reach the near-limit/exhausted
/// badge states without needing a mocked repository. That made this fake
/// internally inconsistent with `FakeGenerationRemoteDataSource`: the
/// badge's "N/10 remaining" and the actual `/generate/*` quota-exceeded
/// error were two disjoint counters that could — and, once observed
/// manually, did — disagree (badge shows room left, Generate still throws
/// `quotaExceeded`, or vice versa). `getQuota()` is now a pure read;
/// [recordTextCall]/[recordImageCall] are the only way these counters
/// move, called by `FakeGenerationRemoteDataSource` exactly when it
/// accepts a `/generate/*` call — see that class for why usage is recorded
/// on acceptance, not only on eventual success. A developer who wants to
/// manually walk the badge toward its exhausted state should just make a
/// few real Generate calls now, which is what a real backend's usage would
/// require too.
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

  /// True once a `/generate/text` call would be rejected for quota —
  /// `FakeGenerationRemoteDataSource.generateText` checks this before
  /// doing any (fake) work.
  bool get isTextQuotaExceeded => _textCallsUsed >= _textCallsLimit;

  /// Same as [isTextQuotaExceeded], for `/generate/image`.
  bool get isImageQuotaExceeded => _imageCallsUsed >= _imageCallsLimit;

  /// Records one accepted `/generate/text` call. Clamped at the limit
  /// rather than incrementing past it, though callers are expected to
  /// check [isTextQuotaExceeded] first and never reach this once exceeded.
  void recordTextCall() {
    _textCallsUsed = (_textCallsUsed + 1).clamp(0, _textCallsLimit);
  }

  /// Same as [recordTextCall], for `/generate/image`.
  void recordImageCall() {
    _imageCallsUsed = (_imageCallsUsed + 1).clamp(0, _imageCallsLimit);
  }

  @override
  Future<QuotaDto> getQuota() async {
    await FakeBackendSupport.latency();

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
