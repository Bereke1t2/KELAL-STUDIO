---
name: flutter-ethiopic-typography
description: Font bundling, line-height, safe zones, and the golden-image regression corpus for correct Ethiopic (Amharic) text rendering in the Kelal Studio Flutter app. Use whenever touching core/theme/app_typography.dart, core/render_engine, any text-layer/canvas editing code, or any widget that displays Amharic text.
---

# Ethiopic Typography

The PRD names "Ethiopic Text Line Collision" as its **highest-rated risk**
(preview not matching export, or Ethiopic text rendering incorrectly).
Treat every rule below as load-bearing, not stylistic preference.

## Font

- Production font is **Noto Sans Ethiopic**
  (`assets/fonts/NotoSansEthiopic-Regular.ttf`, bundled, SIL OFL 1.1 —
  license text must ship in a third-party-license screen, see
  `flutter-review-checklist`). Figma's own design proofs use Abyssinica
  SIL only because Noto Sans Ethiopic isn't in Figma's font catalog —
  **never** use Abyssinica SIL, or any font other than Noto Sans Ethiopic,
  in the actual app.
- Font fallback is explicit and bundled, **never system-font-dependent**.
  A missing glyph must never render as an empty box (tofu) — if you
  introduce a code path that can render text outside the bundled font's
  coverage (e.g. an emoji, a rare symbol), that's a bug to fix, not an
  acceptable edge case.
- Mixed-script runs (Amharic + Latin brand name + digits + hashtags in
  one caption) must render from the single bundled family — don't
  special-case Latin substrings into a different font, even for a "nicer"
  Latin look; a visible baseline/weight mismatch mid-line is exactly the
  bug this rule prevents.

## Line height — fixed, not adjustable per style

`AppTypography.lineHeightMultiplier = 1.55` applies to **every** text
style (`core/theme/app_typography.dart`). This isn't a default that
individual styles can override — Latin's typical ~1.2 line-height is the
PRD's named collision source for Ethiopic's taller glyphs/marks. If a
design calls for a visually tighter block of text, adjust spacing between
elements, not this multiplier.

## Hierarchy: size, spacing, color — never weight

Every `AppTypography` style is `FontWeight.w400` deliberately, matching
the single-weight family the Figma type scale proofs with ("Hierarchy
comes from size, spacing and color — never weight"). Don't reach for
`FontWeight.bold` to add emphasis in Amharic text; use `AppTypography`'s
existing size/color distinctions (e.g. `title` vs `body`, or
`context.colors.textPrimary` vs `textSecondary`) instead.

## Line breaking

Break at space, U+1361 (Ethiopic word separator), or U+1362 (Ethiopic
full stop) — never mid-syllable. Flutter's default line breaker already
treats these as break opportunities (they're Unicode word-separator/
terminator punctuation), so no custom `LineBreaker` should be needed —
but this is an assumption to verify against the golden corpus below, not
something to take on faith when writing new text-layout code. If you
observe a mid-syllable break in a golden diff, that's a real bug, not
noise.

## Render engine is the single source of truth

`core/render_engine/render_engine.dart`'s `RenderEngine.paint()` is used
by **both** the live canvas editor preview and `RenderEngine.exportPng()`
for the final exported asset. Any Ethiopic-specific text layout fix
belongs in that one function — never add a second, "simplified" text
painting path for the editor's live preview. Two implementations
diverging is exactly the PRD's #1 risk.

## Golden-image regression corpus (PRD §6.7 — required, not optional)

Build and maintain a fixed corpus of Amharic test strings covering: short
text, long text, mixed-script (Amharic + Latin + digits + hashtag),
punctuation-heavy text, and the worst-case longest real word you can find
— rendered at every supported output size. Store as `alchemist` golden
tests under `test/goldens/`, run in CI on every commit (see
`.github/workflows/mobile-ci.yml`'s dedicated golden job), failing the
build on any pixel deviation beyond alchemist's default threshold. When
adding new Ethiopic-text-rendering UI, add to this corpus rather than
assuming existing coverage is sufficient — see `flutter-testing` skill
for the golden-test mechanics.

## Minimum rendered size

There is a floor below which Ethiopic's distinguishing marks become
illegible — this must be measured empirically against real output
resolution, not assumed from a Latin-text minimum-font-size convention.
If you're adding a UI surface that lets Ethiopic text render below the
existing smallest `AppTypography` style (`caption`, 12px), flag it rather
than assuming it's fine.
