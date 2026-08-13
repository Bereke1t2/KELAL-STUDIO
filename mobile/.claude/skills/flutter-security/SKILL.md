---
name: flutter-security
description: Strict, OWASP MASVS-aligned security checklist for the Kelal Studio Flutter app — token storage, secrets, obfuscation, dependency scanning, cert pinning, root/jailbreak detection. Use on every change touching auth, storage, networking, build config, or a new third-party dependency, and always as part of the mandatory pre-commit review.
---

# Flutter Security

This is a **strict** gate, per explicit product direction — when in doubt,
flag it rather than wave it through. Every item below is checked by
`flutter-review-checklist` on every commit, not just when "working on
security."

## Tokens & secrets

- JWT access/refresh tokens: `flutter_secure_storage` only
  (`core/storage/secure_token_storage.dart` is the *only* class allowed to
  read/write them). **Never** `shared_preferences`, a plain file, or a
  Bloc/widget field that could end up in a crash report or debug print.
- Zero AI-provider API keys anywhere under `mobile/`, ever — that's a
  hard PRD requirement (a key shipped in an app binary is a published,
  compromised key the moment the binary is distributed). All generation
  calls proxy through the backend, mock or real.
- No secret in a `.env` file bundled as a Flutter asset — it's trivially
  extracted from a release build by unzipping the APK/IPA. Build-time
  config goes through `envied` (obfuscated at compile time) +
  `--dart-define-from-file`.
- Verbose request/response logging (`PrettyDioLogger` in
  `core/network/dio_client.dart`) is wrapped in `assert()` specifically so
  it's stripped from release builds — don't remove that guard, and don't
  add a second logger that isn't similarly guarded. It can otherwise leak
  prompts, tokens, or PII into device logs.

## Auth flow specifics (PRD §6.1 — don't relax these)

- Wrong password -> generic "invalid credentials," never reveal which
  field was wrong.
- Password-reset-request responds identically whether or not the email
  exists (anti-enumeration) — don't add a branch that reveals account
  existence, even for a "helpful" UX message.
- Refresh-token reuse (an already-consumed refresh token presented again)
  is a compromise signal — on detection, clear both tokens and force
  re-authentication. Never silently reissue tokens after a failed/expired
  refresh.
- Concurrent 401s must trigger exactly one refresh attempt
  (`AuthInterceptor._refreshInFlight` single-flight lock), not one refresh
  per in-flight request — a naive per-request refresh looks like
  refresh-token reuse to the backend's rotation/reuse-detection and can
  force spurious logouts.

## Build & release

- `flutter build appbundle/ipa --obfuscate --split-debug-info=<path>` is
  non-negotiable for any release build — never ship an unobfuscated
  release artifact. Keep the debug-symbol map off-device (CI artifact
  only) so crash stack traces can still be de-obfuscated.
- Dependency vulnerability scanning (`osv-scanner` against
  `pubspec.lock`) runs in CI on every change, not as a one-off audit —
  see `.github/workflows/mobile-ci.yml`.
- A new third-party dependency is itself a security-relevant change:
  check it's actively maintained, check its permissions/platform
  requirements make sense for what it claims to do, and flag anything
  that reads like it wants more access than its stated purpose (camera,
  contacts, location, background execution) unless the task actually
  requires it.

## Certificate pinning — off by default, on purpose

Implemented via a `SecurityContext` on the Dio `HttpClientAdapter`
(preferred over a fingerprint-only package — it layers on top of, rather
than replacing, platform TLS validation) but **not enabled by default**.
This is a deliberate PRD decision (§7.8): pinning complicates incident
recovery (a compromised/rotated cert can lock out an already-shipped app
version), so turning it on is a conscious, explicit choice behind a
config flag — not something to flip on reflexively because "security."

## Root/jailbreak detection — defense-in-depth only

Treat as a weak, easily-bypassed signal, not a hard gate. Do not block a
rooted/jailbroken device from using the app by default — that punishes
legitimate custom-ROM users for a check skilled attackers routinely
bypass anyway. Only add a hard block if a specific compliance requirement
demands it, and flag that requirement explicitly rather than assuming one
exists.

## What "strict" means in review

The `flutter-code-reviewer` subagent treats any of the following as a
CONFIRMED-severity finding, not a nitpick: a secret or token outside
`SecureTokenStorage`/`envied`, a raw `DioException`/HTTP status leaking
into UI copy, a new dependency with no maintenance signal, a release
build config missing `--obfuscate`, or logging that could include a
user's prompt/PII in a non-debug build.
