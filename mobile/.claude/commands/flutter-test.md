---
description: Full unit + widget + golden test run with a coverage summary.
allowed-tools: Bash(fvm flutter test *), Bash(fvm flutter pub *), Read
---

Run the full test suite and report a clear summary — this is a status
check, not a fix-everything command, though obvious/trivial fixes
(a stale golden that's actually correct and just needs regenerating with
`--update-goldens` after visual confirmation, an import fix) are fine to
apply.

1. `fvm flutter test --coverage` from `mobile/`.
2. If any test fails, show the failure output and diagnose — don't just
   report "N tests failed" without the actual assertion diff.
3. If a golden test fails, distinguish two cases explicitly:
   - The rendered output actually regressed (a real bug) — fix the code,
     don't touch the golden.
   - The visual change was intentional (e.g. a deliberate theme/token
     change from this session) — confirm that with the user or the
     conversation context before running
     `fvm flutter test --tags golden --update-goldens`, and say
     explicitly that you regenerated goldens and why.
4. Summarize coverage: total percentage, and call out specifically if
   `lib/core/` or any `domain/` directory is below the near-100% target
   `flutter-testing` sets for domain code.
5. Report pass/fail counts by category (unit/widget/golden) if
   distinguishable from output, plus any flaky-looking test (one that
   passed on a rerun without a code change) as a finding worth a human
   look, not something to silently ignore.
