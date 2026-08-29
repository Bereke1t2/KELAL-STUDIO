/// Mirrors `GenerateTextRequest.platform`'s enum in
/// mobile/api_contract/openapi.yaml (`[instagram, tiktok, telegram]`) —
/// the three destinations PRD §6.2's "platform switcher formats captions
/// for". Pure Dart, no Flutter import — see
/// mobile/.claude/skills/flutter-architecture/SKILL.md's domain-purity
/// rule.
enum ContentPlatform {
  instagram,
  tiktok,
  telegram;

  /// The exact wire value this maps to, kept explicit (not derived from
  /// `.name`) so a future Dart-side rename (or reorder) can't silently
  /// change what gets sent over the wire — `.name` would happen to match
  /// today, but nothing should depend on that coincidence.
  String get wireValue => switch (this) {
    ContentPlatform.instagram => 'instagram',
    ContentPlatform.tiktok => 'tiktok',
    ContentPlatform.telegram => 'telegram',
  };
}
