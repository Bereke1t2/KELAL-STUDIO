# Kelal Studio

A bilingual (Amharic/English) AI content-generation app for Ethiopian
businesses. Compose an idea, generate a caption + on-brand graphic, edit it,
export it — from a phone. See `docs/Kelal_Studio_PRD.pdf` for the full
product spec.

## Layout

| Path | What it is | Stack | Status |
|---|---|---|---|
| `mobile/` | The Flutter app — the product's primary surface | Flutter/Dart | Built (P0 feature set) |
| `backend/` | The Go API everything talks to | Go · Gin · GORM · PostgreSQL | Auth/Brand Kit/Assets/Admin done; generation/quota/reminders have real logic behind a spec that still marks them `stub` (see `backend/docs/FEATURE_OWNERSHIP.md`) |
| `web/` | Admin/Brand-Kit portal | React · TypeScript · Vite | Scaffolded — auth + Brand Kit + admin surface exist; not the primary surface |
| `docs/` | PRD and reference material | — | — |

Each package has its own `README.md` and `CLAUDE.md` with the deep,
package-specific detail (architecture, conventions, commands). This file is
the one thing none of them cover on their own: **how to get all of them
running together, on your machine, from a clean clone.**

## Run everything locally

You need three terminals: backend, then (mobile *or* web, or both).

### 1. Backend

```bash
cd backend
make tidy                 # resolve Go deps (first time only)
cp .env.example .env      # your local config — see "Environment & credentials" below
USE_MOCK_DATA=true make run
# API on http://localhost:8080 — health check: curl localhost:8080/healthz
# Interactive API docs (non-production only): http://localhost:8080/docs
```

`USE_MOCK_DATA=true` runs entirely on in-memory repositories — no Postgres,
no setup, and it's what you want for a quick local run. For a real database
instead:

```bash
make db-up      # starts Postgres via docker compose
make migrate    # applies the schema
make run        # USE_MOCK_DATA=false in your .env
```

### 2. Mobile

The app defaults to `Env.useMockApi = true` — mobile's own in-app fakes, no
backend required at all. To run against the backend you just started
instead:

```bash
cd mobile
fvm flutter pub get
dart run build_runner build --delete-conflicting-outputs
fvm flutter run \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8080/v1
```

**The trailing `/v1` is not optional** — the backend mounts every route
under `/v1` (`backend/api/openapi.yaml`'s `servers:` entry), but mobile's
own route paths (`/auth/login`, `/generate/text`, …) don't repeat it, so
`API_BASE_URL` has to supply it.

**Emulator/device networking**, the thing that actually trips people up:

- iOS Simulator: `http://localhost:8080/v1` works as-is.
- Android Emulator: the emulator's `localhost` is itself, not your machine —
  use `http://10.0.2.2:8080/v1` instead.
- A real physical device: use your machine's LAN IP (`http://192.168.x.x:8080/v1`),
  and make sure the backend and the phone are on the same network — `HTTP_PORT`
  in `backend/.env` binds to all interfaces by default.

### 3. Web

```bash
cd web
npm ci
npm run dev        # http://localhost:5173, proxies /v1 -> http://localhost:8080
```

No env var needed for local dev — `vite.config.ts` proxies `/v1` straight to
the backend (override the target with `VITE_API_TARGET` if your backend
isn't on the default port).

## Environment & credentials

**Only the backend has real environment/credential files — mobile and web
never hold a secret.** That split is deliberate, not incidental (PRD §7.8,
§10.1): every AI-provider key, JWT signing secret, database password, and
SMTP credential lives server-side, in `backend/.env`. If you ever find
yourself about to put an API key in a `--dart-define` or a `VITE_*` variable,
stop — that value ships inside the client binary/bundle and is trivially
extracted.

### `backend/.env`

```bash
cd backend && cp .env.example .env
```

`.env` is gitignored — **never commit it**, and never commit a real secret
into `.env.example` either (it stays as documentation with obviously-fake
placeholder values). The file is fully commented; the sections that matter
most when you're getting a real backend running, not just the mock:

- **`JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`** — long random strings. The
  server refuses to boot with the shipped dev defaults when `APP_ENV=production`.
- **`DATABASE_URL`** (or the `DB_*` parts) — ignored entirely while
  `USE_MOCK_DATA=true`.
- **`EMAIL_PROVIDER`** — `log` (default) just logs verification/reset emails
  to the console, which is genuinely fine for local dev; the server refuses
  to boot with it in production. Set `smtp` + `EMAIL_SMTP_*` for a real send.
- **`TEXT_PROVIDER_ORDER` / `IMAGE_PROVIDER_ORDER` / `VIDEO_PROVIDER_ORDER`**
  — left at `stub` (deterministic fakes) until a real AI provider is chosen
  (OQ-20, still open). The matching key lines (`GEMINI_API_KEY`, etc.) are
  commented out — uncomment and fill in only the one(s) you're actually
  switching on, and only server-side, only in `.env`.
- **`MODERATION_PROVIDER`** — `stub` fails closed (refuses everything, no
  key needed); `openai` needs `OPENAI_API_KEY`.

### Mobile — no `.env`, build-time flags instead

Mobile has no credential file at all. Its only configuration is two
`--dart-define` flags at build/run time (`mobile/lib/core/env/env.dart`):
`USE_MOCK_API` (default `true`) and `API_BASE_URL`. Both are non-secret —
they select *which server to talk to*, never *how to authenticate to it*
beyond the normal login flow.

### Web — no `.env` either, for the same reason

`VITE_API_TARGET` (dev-only, see above) is the only configuration web reads,
and it's just a proxy target, never a credential.

## Running the full stack against real Postgres + a real provider

Once you've done the mock-mode quickstart above and want the real thing:

1. `cd backend && make db-up && make migrate`
2. In `backend/.env`: set `USE_MOCK_DATA=false`, real `DATABASE_URL`/`DB_*`,
   real `JWT_*_SECRET` values, and (if you want generated content to be
   real rather than the deterministic stub) uncomment and fill in a
   provider key, then set e.g. `TEXT_PROVIDER_ORDER=gemini` /
   `IMAGE_PROVIDER_ORDER=gemini`.
3. `make run`
4. Point mobile/web at it exactly as in the quickstart above — nothing
   about the client-side setup changes between mock and real backend modes.

**Known gap, flagged rather than glossed over:** mobile's real-backend
integration was built against the backend's contract but has not been
exercised end to end against a live server outside this repo's own CI —
walk the core flows by hand (register → verify → login, compose → generate
→ edit → export, Brand Kit save/logo upload) the first time you connect a
real backend, the same way you would after any first real integration.

## Hosting

Nothing in this repo is wired to a specific cloud target yet — no deploy
pipeline, no chosen provider. What each package gives you to build on:

- **Backend** — `backend/Dockerfile` builds a container image;
  `make build` compiles the `api` and `worker` binaries directly if you'd
  rather run them bare-metal. Either way, at minimum: set every variable
  in the **required in production** category above for real (`APP_ENV=production`
  refuses to boot otherwise), point `DATABASE_URL` at a real Postgres, run
  `make migrate` against it once, and run the `api` process behind TLS.
  `cmd/worker` (`make worker`, or the `bin/worker` binary `make build`
  produces) is the async video-job drainer — a **separate process** you
  must also run, since the default in-process queue means the API alone
  never drains video jobs.
- **Web** — `npm run build` produces a static bundle in `web/dist/`. It's
  built to be served **same-origin** with the backend under `/v1`
  (`vite.config.ts`'s dev-proxy comment says as much) — the simplest real
  deploy is a reverse proxy in front of the `api` binary that serves
  `web/dist/` as static files and forwards `/v1/*` to it, so the built SPA
  needs no separate API-base-URL configuration at all.
- **Mobile** — real store builds need release signing, which **is not
  configured in this repo yet** (`mobile/android/app/build.gradle.kts` has
  an explicit `TODO: Add real release signing config before shipping` —
  see `mobile/CLAUDE.md`'s decisions log). Set that up before attempting a
  real release build. Once signed, a release build points at your hosted
  backend the same way the quickstart above does:
  `flutter build apk --release --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://your-api-host/v1`
  (or `flutter build ipa` for iOS).

## Repo-wide rules

See `CONTRIBUTING.md` for the full commit/PR process. Short version: commits
use Conventional Commits summarizing *why*, not a restatement of the diff;
a change under `mobile/` must go through `/commit`
(`mobile/.claude/commands/commit.md`); PRs are stacked via `gh stack`
(`/pr`), not one-off `gh pr create` calls for multi-part work.
