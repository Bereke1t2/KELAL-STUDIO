---
name: flutter-testing
description: When each test type (unit, widget, golden/screenshot, integration/e2e) is required for the Kelal Studio Flutter app, plus coverage gates and golden-test discipline. Use whenever adding or changing a Bloc, use case, repository, widget, or screen, and always before /commit.
---

# Flutter Testing

Every change needs the test types below that apply to what it touches —
"I'll add tests later" is not an acceptable state to commit in (the
`/commit` review gate checks for this).

## Unit tests — `mocktail` + `bloc_test`

Required for: every use case, every non-trivial repository method, every
Bloc/Cubit. Mock at the interface boundary (`AuthRepository`, not
`AuthRemoteDataSource`, when testing a use case; the data source when
testing the repository impl) — see `test/features/auth/presentation/bloc/login_bloc_test.dart`
for the shape to copy.

For a Bloc using a `bloc_concurrency` transformer, **the transformer's
actual behavior needs its own test**, not just the happy-path single-event
case — e.g. for `droppable()`, fire two events back-to-back in `act` and
assert the underlying use case was called exactly once. A test suite that
only ever fires one event at a time can't tell you whether the transformer
choice actually works.

Target near-100% coverage on `domain/`; the coverage gate in
`.github/workflows/mobile-ci.yml` checks this.

## Widget tests

Required for every new page/significant widget. Register fakes in `getIt`
in `setUp`/`tearDown` (see `test/features/auth/presentation/pages/login_page_test.dart`)
rather than modifying the widget to accept injected dependencies just for
testability — the DI seam already exists, use it.

Cover at minimum: the idle/empty state, a loading state if the widget
triggers an async operation, and both the success and (if applicable)
error-message paths — not just "does it render."

## Golden/screenshot tests — `alchemist`

Scope goldens to **design-system primitives and components**, not whole
screens — full-screen goldens are high-maintenance and flaky (font
rendering, layout timing, platform differences) for little marginal
signal over widget tests. Put them under `test/goldens/`.

Every text-bearing golden should include an Amharic-label variant, not
only English — this is both a design-system consistency check and a
contribution to the Ethiopic golden-image regression corpus mandated by
`flutter-ethiopic-typography`/PRD §6.7. See
`test/goldens/primary_button_golden_test.dart` for the pattern (light/dark
× enabled/disabled × English/Amharic scenarios in one `GoldenTestGroup`).

Run `fvm flutter test --tags golden --update-goldens` only when a visual
change is *intentional* — regenerating goldens to make a failing test
pass without checking the diff is actually correct defeats the point of
the gate.

## Integration/E2E — `integration_test`

Required for critical end-to-end flows as they're built: sign-up → login,
compose → generate → edit → export, and the PRD-mandated draft-continuity
test (start a draft, force-kill the app or toggle airplane mode, reopen,
assert the draft is intact — PRD §6.10's explicit acceptance test, not a
hypothetical). Use `--testMode` to bypass native permission interstitials
in CI. Patrol/Firebase Test Lab are noted as a later addition for
native-interaction-heavy flows (biometrics, OS share sheet verification)
— not required for v1 coverage.

## What blocks `/commit`

`flutter-review-checklist` treats "no test added for a behavior change
that clearly needs one" as a CONFIRMED finding, same severity class as a
correctness bug — a change with no corresponding test isn't "done," it's
unverified.
