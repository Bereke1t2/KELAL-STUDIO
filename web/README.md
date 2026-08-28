# Kelal Studio — Web (React)

The web management portal. **Scope is Brand Kit configuration + admin
oversight only** (PRD §4); the composer is mobile-only and this portal never
generates content. Under the descope ladder (PRD §5.6) the portal collapses to
exactly this surface, so it is built that way from the start.

- **Stack:** React 19 · TypeScript · Vite (SPA) — no SSR/SEO requirement, the
  whole portal sits behind a login.
- **Contract:** `../backend/api/openapi.yaml` is the source of truth. Only
  **auth** and **brand-kit** are implemented server-side; every `/admin/*`
  route currently returns `not_implemented` (501). See
  `../backend/docs/FEATURE_OWNERSHIP.md`.

## Quickstart

```bash
npm ci
npm run dev        # proxies /v1 to http://localhost:8080 (override: VITE_API_TARGET)
```

Run the backend alongside it with `cd ../backend && USE_MOCK_DATA=true make run`.

## Commands

```
npm run dev         # dev server
npm run typecheck   # tsc, must be clean before commit
npm run build       # production bundle
```

## Conventions

- Dependency versions are pinned **exactly** (no `^`, no ranges), matching
  `mobile/pubspec.yaml`'s deliberate policy. Bumping a package is its own
  reviewed change.
- Design tokens come from the Kelal Studio Figma file
  (`0dIrGk2LyVEseP6Tz1KxMa`) — the same source the Flutter app's
  `lib/core/theme/` encodes. Never hardcode a hex or px value.
- Never resolve one of the PRD's open questions by picking the plausible
  option — flag it and stop (see `../backend/docs/OPEN_QUESTIONS.md`).
