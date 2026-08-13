---
description: Run the integration_test suite with --testMode against a connected device or emulator.
allowed-tools: Bash(fvm flutter devices), Bash(fvm flutter test integration_test *), Read
---

Run the end-to-end suite under `integration_test/`.

1. `fvm flutter devices` — if no device/emulator is attached, say so
   explicitly and stop; don't silently skip e2e or fall back to something
   else and call it done.
2. `fvm flutter test integration_test --dart-define=FLUTTER_TEST_MODE=true`
   (or the project's actual `--testMode` invocation once one is wired up —
   check `integration_test/` for the established pattern before assuming
   the exact flag name).
3. Report each scenario's pass/fail explicitly, especially:
   - The draft-continuity flow (PRD §6.10: create a draft, kill the app or
     toggle airplane mode, reopen, assert the draft survived) once it
     exists — this is a named PRD acceptance test, not a nice-to-have.
   - Any flow touching the OS Share Sheet or clipboard: per PRD §6.11,
     the app must never read the clipboard programmatically — if a test
     appears to assert clipboard *contents* by reading them back
     programmatically from app code (rather than the test harness), flag
     that as a policy violation risk, not just a test detail.
4. If a scenario fails, include the actual failure output, not just a
   pass/fail line — e2e failures are expensive to reproduce blind.
