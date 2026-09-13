# Kelal Studio — Web (React)

The web management portal for **Kelal Studio**.

> [!IMPORTANT]
> ### Scope Boundary: Brand Kit & Admin Oversight Only
> The web portal is **strictly limited to Brand Kit configuration and admin oversight** (PRD §4).
> 
> **The portal never generates content.** The composer, canvas editor, drafts, raster export, video generation, and reminders are mobile-only surfaces (under the PRD §5.6 descope ladder). The web app is purpose-built for business owners to configure their brand identity (logos, colors, typography, tone of voice) and for administrators to monitor platform usage, review flagged content, and adjust user quota limits.

- **Stack:** React 19 · TypeScript · Vite · Tailwind CSS 4 · React Router 8
- **Contract:** [`../backend/api/openapi.yaml`](../backend/api/openapi.yaml) is the source of truth for all API interactions. Authentication, Brand Kit management, and Admin oversight endpoints are fully implemented server-side.
- **Reference Spec:** [`../docs/Kelal_Studio_PRD.pdf`](../docs/Kelal_Studio_PRD.pdf)

---

## Tech Stack

All dependency versions are pinned exactly in [`package.json`](package.json) to ensure consistent builds:

| Package / Tool | Exact Version | Purpose |
|---|---|---|
| **React** | `19.2.8` | Core UI library (`react` & `react-dom`) |
| **TypeScript** | `7.0.2` | Application type safety |
| **Vite** | `8.2.2` | Fast bundler and development server (`@vitejs/plugin-react: 6.1.0`) |
| **Tailwind CSS** | `4.3.3` | Utility styling (`@tailwindcss/vite: 4.3.3`) bridging CSS-variable design tokens |
| **React Router** | `8.3.0` | Client-side routing for authenticated portal views |
| **Vitest** | `4.1.11` | Fast unit and component test runner (`jsdom: 30.0.1`) |
| **oxlint** | `1.80.0` | High-performance linter |

---

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

---

## Kept foundation (do not rewrite)

- `src/styles/tokens.css` — design tokens, pulled from the Kelal Studio Figma
  file (`0dIrGk2LyVEseP6Tz1KxMa`), the same system the Flutter app encodes in
  `mobile/lib/core/theme/`. Never hardcode a hex or px — go through a token.
- `src/api/*` — typed client with single-flight token refresh and an
  error-code taxonomy. `src/api/types.ts` transcribes the OpenAPI shapes.
- `src/auth/AuthContext.tsx`, `src/theme/ThemeContext.tsx` — session restore and
  the `data-theme` controller.

---

## Fonts

Self-hosted, subset, weight 400 only — see [`FONTS.md`](./FONTS.md). Amharic is
never system-font-dependent (PRD §6.7); a missing glyph as a box is prohibited.

---

## Quickstart

```bash
# 1. Install dependencies
npm ci

# 2. Start Vite dev server (proxies /v1 -> http://localhost:8080)
npm run dev
```

The portal runs locally at **`http://localhost:5173`**.

### Running Alongside the Backend

Start the Go API in mock mode in a separate terminal:

```bash
cd ../backend && USE_MOCK_DATA=true make run   # :8080, in-memory data, permissive moderation
```

> [!NOTE]
> - `vite.config.ts` automatically proxies `/v1` requests to `http://localhost:8080`. Override the proxy target with `VITE_API_TARGET` if the backend is on an alternate port.
> - Mock backend mode prints verification and password-reset tokens to the server terminal.
> - Mock mode contains **no admin user** by default; accessing `/admin/*` screens requires a real PostgreSQL backend and an explicit role grant: `UPDATE users SET role='admin' WHERE email='...';`.

---

## Commands

| Command | Purpose |
|---|---|
| `npm run dev` | Starts the Vite development server with API proxying on `:5173` |
| `npm run build` | Compiles the production bundle (`tsc -b && vite build`) into `dist/` |
| `npm run typecheck` | Runs `tsc -b --noEmit` (**must pass before commit**) |
| `npm run lint` | Runs `oxlint` |
| `npm run test` | Runs test suite via Vitest (`vitest run`) |
| `npm run test:watch` | Runs Vitest in interactive watch mode |
| `npm run preview` | Serves the local production build from `dist/` |

---

## Deployment & Hosting

Production deployment instructions are detailed in the [Root README.md's Hosting Section](../README.md#hosting--production-deployment).

- Running `npm run build` produces an optimized static SPA bundle in `web/dist/`.
- The web portal is designed to be hosted **same-origin** with the Go backend behind a reverse proxy (e.g., Nginx, Caddy, or Cloudflare). The proxy serves `web/dist/` for frontend routes and forwards `/v1/*` directly to the Go API process. This eliminates CORS complexities and avoids configuring an explicit API base URL in the production client bundle.

---

## Conventions

- **Exact Dependency Pinning**: Dependency versions are pinned **exactly** (no `^`), matching `mobile/pubspec.yaml`'s policy. Bumping a package is its own reviewed change.
- **Bilingual Interface (EN/AM)**: Interface strings are localized in English and Amharic. Amharic strings are best-effort placeholders pending native-speaker review (mirroring the mobile policy); CI enforces that EN/AM translation keys remain synchronized.
- **Do Not Silently Resolve Open Questions**: Never resolve one of the PRD's open questions by picking the plausible option — flag it in code and stop (see [`../backend/docs/OPEN_QUESTIONS.md`](../backend/docs/OPEN_QUESTIONS.md)). Items the portal implements around and flags: brand-kit id discovery, no `GET /assets/{id}`, no `GET /admin/users` roster, tri-state per-user quota, no numeric metric targets (usage tiles stay neutral), and refresh-token storage.
