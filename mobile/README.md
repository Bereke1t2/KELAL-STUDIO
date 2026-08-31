# Kelal Studio — Mobile

The Flutter app (iOS + Android) — Kelal Studio's primary, load-bearing
surface. Bilingual (Amharic/English) AI content generation for Ethiopian
businesses: compose an idea, generate a caption + on-brand graphic, edit it,
export it.

- **Deep architecture/convention detail lives in `CLAUDE.md` and
  `.claude/skills/`** — read those before touching architecture, security,
  performance, typography, or tests. This file is just "how do I get it
  running."
- **Full-stack setup** (running the real backend/web alongside this app,
  where credentials go, hosting) is in the repo root `README.md`, not here
  — this file covers mobile on its own, defaulting to its built-in mock API.

## Quickstart

```bash
fvm flutter pub get                                            # deps
dart run build_runner build --delete-conflicting-outputs       # codegen (freezed/injectable/retrofit/drift/envied)
fvm flutter gen-l10n                                            # only needed after editing an .arb file
fvm flutter run                                                 # runs against the built-in mock API — no backend needed
```

Always prefix Flutter/Dart commands with `fvm` — the pinned SDK (`.fvmrc`)
is what CI and golden-test baselines assume; the system Flutter can silently
shift golden pixels or codegen output.

Login with the seeded demo account in mock mode: `demo@kelalstudio.app` /
`password123`.

### Running against a real backend instead

```bash
fvm flutter run \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8080/v1
```

See the repo root `README.md`'s "Run everything locally" section for the
backend side of this (including the Android-emulator-vs-`localhost`
gotcha) — mobile holds no credentials of its own; `API_BASE_URL` just picks
which server to talk to.

## Everyday commands

```bash
fvm flutter analyze                                             # must be clean before /commit
fvm flutter test --coverage                                     # unit + widget + golden
fvm flutter test --tags golden --update-goldens                 # only when a visual change is intentional
dart format --set-exit-if-changed .                             # must be clean before /commit
```

## Committing

A change under `mobile/` must go through `/commit`
(`.claude/commands/commit.md`) — a repo-root hook blocks a raw `git commit`
on staged `mobile/**` changes otherwise. See the repo root `CONTRIBUTING.md`.
