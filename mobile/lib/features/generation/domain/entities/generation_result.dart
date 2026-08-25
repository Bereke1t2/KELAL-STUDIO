import 'package:equatable/equatable.dart';

/// Pure-Dart domain entity — no Flutter, no json, no dio imports here (see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule). Mirrors `GenerateTextResponse` in
/// mobile/api_contract/openapi.yaml (`caption_en`, `caption_am`,
/// `call_to_action`, `hashtags`), plus [isFallback] (see its own doc
/// comment — not part of the wire contract).
class GenerationResult extends Equatable {
  const GenerationResult({
    required this.captionEn,
    required this.captionAm,
    required this.callToAction,
    required this.hashtags,
    required this.isFallback,
  });

  final String captionEn;
  final String captionAm;
  final String callToAction;

  /// 5-8 entries per `GenerateTextResponse.hashtags`'
  /// `minItems`/`maxItems` — this entity doesn't re-validate that range
  /// itself (it's a pure pass-through of whatever the backend/fake
  /// returned), the same "don't invent numbers the contract already
  /// owns" stance `Quota` takes on its own limits.
  final List<String> hashtags;

  /// True when this content came from the PRD §6.2 fallback path: "on LLM
  /// timeout/failure, return a pre-cached template response rather than a
  /// raw error." **Not part of `GenerateTextResponse`'s wire schema** — a
  /// real backend's own fallback substitution is meant to arrive as an
  /// ordinarily-shaped 200 response, indistinguishable on the wire from a
  /// fresh generation. This field exists purely so the mock-mode fake
  /// (`FakeGenerationRemoteDataSource`) can simulate that PRD-described
  /// behavior in a way the UI can be transparent about — see
  /// `GenerateTextResponseDto`'s doc comment for exactly how it's threaded
  /// through without becoming part of the real request/response contract.
  /// Always `false` for any response actually parsed from JSON (real
  /// backend or otherwise).
  final bool isFallback;

  @override
  List<Object?> get props => [
    captionEn,
    captionAm,
    callToAction,
    hashtags,
    isFallback,
  ];
}
