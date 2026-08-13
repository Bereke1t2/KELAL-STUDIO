---
name: flutter-networking-data
description: dio/retrofit conventions, the repository pattern, the mock-vs-real data source switch, and Drift local persistence discipline for the Kelal Studio Flutter app. Use whenever adding a data source, a repository, an API call, or anything touching local draft storage.
---

# Flutter Networking & Data

## The repository pattern, concretely

```
domain/repositories/foo_repository.dart      # interface, Result-returning
data/repositories/foo_repository_impl.dart   # implementation: try/catch around the data source, maps to Result
data/datasources/foo_remote_data_source.dart # abstract interface
data/datasources/foo_api.dart                # @RestApi retrofit client (real)
data/datasources/real_foo_remote_data_source.dart   # wraps the api, maps DioException -> ApiException
data/datasources/fake_foo_remote_data_source.dart   # in-memory, professional mock
data/datasources/foo_datasource_module.dart  # @module: the ONE place that picks fake vs real
```

Copy this shape from `features/auth` when adding a new feature's data
layer — don't invent a different structure per feature.

## dio

One `Dio` instance for the whole app (`core/network/dio_client.dart`) —
never `Dio()` inside a feature. Every retrofit client is constructed from
that instance so `AuthInterceptor` (bearer token attach + single-flight
refresh-on-401) and the verbose-logging-only-in-debug guard apply
uniformly.

## Mapping errors once, at the edge

`core/network/api_exception_mapper.dart` is the only place a
`DioException` gets inspected. It maps to `ApiFailure` using the typed
error taxonomy from `api_contract/openapi.yaml`
(`quota_exceeded`/`provider_timeout`/`moderation_refused`/`malformed_output`/`validation_error`)
— branch UI messaging on `ApiFailure.type`, never on a raw HTTP status
code or a `DioException` reaching outside `data/`.

## The mock-vs-real switch

`Env.useMockApi` (from `--dart-define`, default `true` until a real
backend exists) decides which data source a feature's `@module` provides.
**Never** instantiate `Fake*RemoteDataSource` or `Real*RemoteDataSource`
directly outside that one module file — that's the whole point of the
seam.

A "professional" fake (see `core/network/fake_backend_support.dart`):
- Uses `FakeBackendSupport.latency()` — simulated realistic 3G/4G delay,
  not an instant same-process return. A fake that responds in 5ms hides
  loading-state bugs that only show up against a real network.
- Exercises the typed error taxonomy deliberately (wrong password ->
  generic "invalid credentials" per PRD §6.1, not a made-up message; a
  configurable failure rate for other calls via
  `FakeBackendSupport.maybeFail`) so error-state UI actually gets driven
  during development, not just the happy path.
- Never silently diverges from `api_contract/openapi.yaml`'s documented
  shape — if the fake's response shape and the spec disagree, fix
  whichever one is wrong, don't let them drift.

## `api_contract/openapi.yaml`

This file is a **mobile-local**, hand-authored contract transcribed from
the PRD §11 endpoint skeleton — it is not a promise from a real backend
team (none exists yet in this repo). Keep retrofit `@RestApi` interfaces
in sync with it by hand (there's no automated YAML → Dart step wired up).
When a real backend eventually exists and its actual spec disagrees with
this file, the real spec wins — update this file to match, don't treat it
as authoritative once a real one exists.

## Drift (local drafts)

- `drift`, not Isar (abandoned upstream — do not add it as a dependency
  even if a tutorial suggests it).
- Drafts are device-local only for v1 — no server sync (PRD §6.10's
  explicit decision). Don't build sync machinery "just in case."
- Every schema change needs a migration step, even in early development —
  don't rely on uninstall/reinstall to dodge writing one.
- Required behaviors, not optional polish: autosave on every edit, drafts
  survive force-kill (test this with an actual airplane-mode kill/reopen,
  not just a hot restart — see `flutter-testing`), a cap on stored drafts
  with an eviction policy, graceful behavior when device storage is full,
  and the uninstall-destroys-drafts disclosure surfaced to the user
  somewhere discoverable.

## Secrets

No AI-provider API key, ever, anywhere under `mobile/` — all generation
proxies through the backend (mock or real). If a build-time value must
exist (e.g. a real `API_BASE_URL` for a non-mock build), it goes through
`envied` (`core/env/env.dart`) + `--dart-define-from-file`, never a
`.env` file bundled as an asset — that's trivially extracted from a
release APK/IPA by unzipping it.
