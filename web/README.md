# Kelal Studio — Web (React)

The web management portal. **Scope is Brand Kit configuration + admin oversight**
(PRD §4). The composer, canvas editor, drafts, export, video, and reminders are
mobile-only; under the descope ladder (PRD §5.6) the portal collapses to exactly
Brand Kit + Admin, so it is built that way from the start. **The portal never
generates content.**

- **Stack:** React 19 · TypeScript · Vite (SPA — the whole portal sits behind a
  login, no SSR/SEO need) · React Router 8 · Tailwind CSS 4 (`@theme inline`
  bridging CSS-variable design tokens).
- **Contract:** `../backend/api/openapi.yaml` is the source of truth. Auth,
  Brand Kit, and the Admin surface (usage counts, moderation-flag queue,
  per-user quota limits) are all implemented server-side on `main`.

## Status — rebuild in progress

The portal is being rebuilt on a stack of PRs. This branch
(`refactor/web-teardown-foundation`) is the base: it removes the old screens and
stands up the foundation the rest build on. Stacked on top:

| Branch | Adds |
|---|---|
| `feat/web-i18n-and-shell` | bilingual (EN/AM) i18n layer, restyled UI kit, app shell |
| `feat/web-self-serve-auth` | register · verify email · forgot/reset password · redesigned login |
| `feat/web-brand-kit-and-preview` | Brand Kit form + logo upload + live brand preview |
| `feat/web-admin` | Usage · Flagged prompts · User limits, against the real contract |

## Kept foundation (do not rewrite)

- `src/styles/tokens.css` — design tokens, pulled from the Kelal Studio Figma
  file (`0dIrGk2LyVEseP6Tz1KxMa`), the same system the Flutter app encodes in
  `mobile/lib/core/theme/`. Never hardcode a hex or px — go through a token.
- `src/api/*` — typed client with single-flight token refresh and an
  error-code taxonomy. `src/api/types.ts` transcribes the OpenAPI shapes.
- `src/auth/AuthContext.tsx`, `src/theme/ThemeContext.tsx` — session restore and
  the `data-theme` controller.

## Fonts

Self-hosted, subset, weight 400 only — see [`FONTS.md`](./FONTS.md). Amharic is
never system-font-dependent (PRD §6.7); a missing glyph as a box is prohibited.

## Quickstart

```bash
npm ci
npm run dev        # :5173, proxies /v1 to http://localhost:8080 (override: VITE_API_TARGET)
```

Run the backend alongside it:

```bash
cd ../backend && USE_MOCK_DATA=true make run   # :8080, in-memory data, permissive moderation
```

Mock mode prints verification / password-reset tokens to the server log (there
is no real mailbox) and has **no admin user** — the Admin screens need a real
Postgres backend and a manual `UPDATE users SET role='admin' WHERE email='…'`.

## Commands

```
npm run dev         # dev server
npm run lint        # oxlint  (typescript-eslint does not support this repo's TS 7 yet)
npm run typecheck   # tsc — must be clean before commit
npm run test        # vitest
npm run build       # production bundle (tsc -b && vite build)
```

## Conventions

- Dependency versions are pinned **exactly** (no `^`), matching
  `mobile/pubspec.yaml`'s policy. Bumping a package is its own reviewed change.
- Interface strings are localized EN/AM. Amharic strings are best-effort
  placeholders pending native-speaker review (same policy as `mobile/`); a CI
  test keeps the EN/AM key sets from drifting.
- Never resolve one of the PRD's open questions by picking the plausible option
  — flag it in code and stop (see `../backend/docs/OPEN_QUESTIONS.md`). Items the
  portal implements around and flags: brand-kit id discovery, no
  `GET /assets/{id}`, no `GET /admin/users` roster, tri-state per-user quota,
  no numeric metric targets (usage tiles stay neutral), refresh-token storage.
