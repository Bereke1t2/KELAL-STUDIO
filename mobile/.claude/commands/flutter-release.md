---
description: Release build checklist — pub get, codegen, analyze, test, golden, obfuscated split-per-abi build, version bump.
disable-model-invocation: true
allowed-tools: Bash(fvm flutter pub get), Bash(dart run build_runner *), Bash(fvm flutter analyze), Bash(fvm flutter test *), Bash(fvm flutter build *), Read, Edit
---

Run the full release checklist, in order, stopping at the first failure
rather than pushing through. This is deliberately not something Claude
invokes on its own initiative — only run this when explicitly asked to
prepare a release build.

1. `fvm flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs` — confirm
   no codegen errors (a stale generated file passing analyze but wrong at
   runtime is worse than a build error here).
3. `fvm flutter analyze` — must be completely clean, no exceptions for a
   release build.
4. `fvm flutter test --coverage` — full suite, must pass. Do not proceed
   past a failing test to "just build it anyway."
5. Confirm golden tests specifically passed (not skipped) — a release
   build with unverified Ethiopic typography rendering is exactly the
   PRD's top-rated risk materializing.
6. Confirm `flutter-security` skill's release checklist:
   - `--obfuscate --split-debug-info=<path>` will be part of the build
     command below, not omitted.
   - No `Env.useMockApi` accidentally left `true` for a real release
     build — confirm the `--dart-define` values passed are correct for
     the target environment.
7. Build with explicit flags:
   ```
   fvm flutter build appbundle --obfuscate --split-debug-info=build/symbols --split-per-abi \
     --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=<real-url>
   ```
   (or `ipa` for iOS, adjusting flags per platform conventions).
8. Bump `version:` in `pubspec.yaml` (ask the user for the intended
   version if it's not obvious from context — don't guess a semver bump
   level).
9. Report the build artifact location, the debug-symbol map location (it
   must be kept off-device, e.g. uploaded to CI artifacts / crash
   reporting — never shipped inside the app), and a summary of steps 1-6.

Do not skip step 6's checks even under time pressure — an accidentally
non-obfuscated or mock-API-pointed release build is a shipped-product bug,
not a caught-in-review one.
