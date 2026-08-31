import 'package:equatable/equatable.dart';

/// Pure-Dart domain entity — no Flutter, no json, no dio imports here (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule). Mirrors `Quota` in mobile/api_contract/openapi.yaml.
///
/// **The actual numeric limits are an open product decision** (PRD §2.3
/// explicitly lists per-user/system quota numbers as Open — no target is
/// set anywhere in the PRD or the OpenAPI contract). This entity is a pure
/// pass-through of whatever [textCallsLimit]/[imageCallsLimit] the backend
/// (or, today, the fake data source) reports — it never invents or assumes
/// a number itself. See `FakeQuotaRemoteDataSource`'s doc comment for the
/// clearly-flagged placeholder values used in mock mode.
class Quota extends Equatable {
  const Quota({
    required this.textCallsUsed,
    required this.textCallsLimit,
    required this.imageCallsUsed,
    required this.imageCallsLimit,
    required this.resetsAt,
  });

  final int textCallsUsed;
  final int textCallsLimit;
  final int imageCallsUsed;
  final int imageCallsLimit;

  /// When today's quota window resets. Always UTC on the wire (see
  /// `QuotaDto`); presentation code is responsible for converting to local
  /// time before formatting for display.
  final DateTime resetsAt;

  /// True once [textCallsUsed] has reached (or, defensively, exceeded)
  /// [textCallsLimit] — a simple, pure derived fact kept here rather than
  /// recomputed ad hoc in presentation code (PRD §6.14: quota state must be
  /// clearly explainable to the user, so both "is it exhausted" and the
  /// numbers themselves should have one source of truth).
  bool get isTextExhausted => textCallsUsed >= textCallsLimit;

  /// Image-generation equivalent of [isTextExhausted].
  bool get isImageExhausted => imageCallsUsed >= imageCallsLimit;

  @override
  List<Object?> get props => [
    textCallsUsed,
    textCallsLimit,
    imageCallsUsed,
    imageCallsLimit,
    resetsAt,
  ];
}
