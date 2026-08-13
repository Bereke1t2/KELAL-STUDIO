---
name: flutter-review-checklist
description: The single review rubric (architecture, correctness, performance, edge cases, race conditions, bugs, security-strict, test coverage) used by both /review and /commit and the flutter-code-reviewer subagent for the Kelal Studio Flutter app. Load this before reviewing any diff — do not improvise a different checklist.
---

# Flutter Review Checklist

This is the **single source of truth** rubric — `/review`, `/commit`, and
the `flutter-code-reviewer` subagent all use this exact list so the
checklist can't drift between invocation paths. Report findings ranked
most-severe first; an empty findings list is a valid, expected outcome
for a clean diff — don't invent nitpicks to justify the review having run.

For every item, a finding needs a concrete failure scenario (what input,
what state, what happens) — "this could theoretically be an issue" without
a scenario is not a reportable finding.

## 1. Architecture (see `flutter-architecture`)

- Does `domain/` stay pure Dart (no Flutter/dio/drift/bloc imports)?
- Does presentation call use cases only, never a repository or data
  source directly?
- Is there exactly one use case class per use case, one repository
  interface/impl pair, correctly split across `data`/`domain`?
- Does anything import `core/render_engine` a second, divergent way
  instead of using `RenderEngine.paint`/`exportPng` as the single source
  of truth?
- Does this diff touch one of the PRD's open questions (see
  `flutter-architecture`'s table) without flagging it?

## 2. Correctness / bugs

- Does the code do what it claims, on the actual inputs it will receive
  (not just the one example in a docstring or PR description)?
- Are `Result`/sealed-type switches exhaustive, or is there a case that
  silently falls through?
- Null-safety: any force-unwrap (`!`) that isn't actually guaranteed
  non-null by a prior check in the same scope?

## 3. Race conditions / concurrency

- Every new/changed Bloc event handler: does it have a deliberate
  `bloc_concurrency` transformer (see `flutter-state-management`), or is
  it silently on `concurrent()` without that being a reasoned choice?
- Any place two async operations can write to the same local state (Drift
  row, secure storage, in-memory cache) — is ordering actually guaranteed,
  or can they interleave?
- `AuthInterceptor`-style single-flight patterns: if this diff adds
  another "refresh once, share the result" scenario, does it actually
  share one in-flight future, or can concurrent callers each trigger their
  own?

## 4. Performance (see `flutter-performance`)

- Any image decode inside a paint/build call, instead of decode-once-cache?
- Any full-resolution bitmap held during interactive editing instead of a
  downscaled proxy?
- Any obviously avoidable rebuild (broad `BlocBuilder` where
  `BlocSelector` would do, missing `const`) introduced in a hot path
  (lists, canvas, anything rebuilding per-frame or per-keystroke)?

## 5. Edge cases

- Empty/zero states (empty list, zero drafts, first-run with no brand kit
  configured yet)?
- Failure/offline states: does every new network call handle at least
  `network`, `unauthorized`, and whatever `ApiErrorType` values are
  plausible for that endpoint — not just the success path?
- Device-storage-full, quota-exhausted, and "target app not installed"
  (for Share Sheet flows) — are these product-required edge cases (PRD
  §6.10, §6.14, §6.11) actually handled where the diff touches them, not
  deferred silently?

## 6. Security — strict (see `flutter-security`)

- Any secret, token, or credential outside `SecureTokenStorage`/`envied`?
- Any raw `DioException`, HTTP status, or classifier code surfaced
  directly in UI copy instead of a mapped, plain-language `ApiFailure.message`?
- Any new dependency added — is it justified, actively maintained, and
  does its access footprint (permissions, platform capabilities) match
  what it's actually used for?
- Release build config: still has `--obfuscate --split-debug-info` if
  this diff touches build/release scripts?

## 7. Test coverage (see `flutter-testing`)

- Does a behavior change have a corresponding unit/widget/golden test, or
  is it landing unverified?
- For a new `bloc_concurrency` transformer choice, is there a test that
  actually exercises the concurrent-event scenario, not just one event?

## 8. Ethiopic/i18n correctness (see `flutter-ethiopic-typography`) — when the diff touches text rendering

- Fixed 1.55 line-height preserved, not overridden per-style?
- No font other than the bundled Noto Sans Ethiopic introduced for any
  text that might contain Ethiopic script?
- Any hierarchy achieved via `FontWeight.bold` instead of size/spacing/color?

## Severity guide

- **CONFIRMED**: verified against the actual code (traced the call path,
  or ran/read the relevant test) — not merely "this pattern looks risky."
- **PLAUSIBLE**: a real concern that couldn't be fully verified without
  running the app/tests — still report it, labeled as such, don't silently
  drop it because it's unconfirmed.

`/commit` blocks on any CONFIRMED finding at high/critical severity.
PLAUSIBLE and lower-severity findings are surfaced to the user, who can
acknowledge and proceed.
