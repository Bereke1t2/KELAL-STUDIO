/// Mirrors `GenerateTextRequest.input_lang`'s enum in
/// mobile/api_contract/openapi.yaml (`[en, am, auto]`) — the Idea
/// Composer's EN/AM/Auto language toggle. `auto` defers language
/// detection to the backend (PRD §6.2: "Free-text input, English or
/// Amharic, with automatic language detection") rather than the client
/// guessing — see `mobile/.claude/skills/flutter-architecture/SKILL.md`'s
/// "Idea Composer input" open-question row: this enum deliberately never
/// forces a single-language assumption on the input text itself, it only
/// carries the user's explicit choice (or explicit deferral) through to
/// the backend unchanged.
enum InputLanguage {
  en,
  am,
  auto;

  /// The exact wire value this maps to — see `ContentPlatform.wireValue`'s
  /// doc comment for why this isn't derived from `.name`.
  String get wireValue => switch (this) {
    InputLanguage.en => 'en',
    InputLanguage.am => 'am',
    InputLanguage.auto => 'auto',
  };
}
