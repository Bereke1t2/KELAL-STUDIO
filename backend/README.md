# Kelal Studio — Backend (Go API)

The central REST API and asynchronous worker for **Kelal Studio**. It powers authentication, brand identity management, secure image upload/sanitization, and localized Amharic/English AI content generation (captions, graphics, and video) for the mobile and web clients. Built in a **feature-first Clean Architecture**, the codebase enables independent feature slices to be developed in parallel with near-zero merge conflicts.

- **Stack:** Go 1.25 · Gin · GORM · PostgreSQL · JWT · slog
- **Spec:** [`api/openapi.yaml`](api/openapi.yaml) is the source of truth for the HTTP contract — browse it as interactive Swagger UI at `/docs` when running outside production. The PRD is [`../docs/Kelal_Studio_PRD.pdf`](../docs/Kelal_Studio_PRD.pdf).
- **Read next:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (layering & design rules), [`docs/FEATURE_OWNERSHIP.md`](docs/FEATURE_OWNERSHIP.md) (slice ownership map), [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md) (flagged open questions).

> [!NOTE]
> ### Design Principles
> The backend enforces strict **Clean Architecture with inward-pointing dependencies**: feature slices (`internal/features/*`) **never import each other**, sharing code solely through `internal/platform/*` and `internal/models`. Domain models and service methods remain pure and decoupled from infrastructure (Gin lives strictly in `handler.go`/`routes.go`, GORM strictly in `repository.go`). No feature directly communicates with an AI provider; all generative calls route through `internal/platform/provider` (the Provider Abstraction Layer), which manages failover chains, timeouts, and error mappings. Finally, every error crossing a boundary is returned as a typed `*apperror.Error` rendered into a uniform JSON contract, and in-memory mock repositories mirror production repositories 1-to-1 so the entire system can boot and test without external dependencies.

---

## Feature Status

Current slice implementation status tracked directly from [`docs/FEATURE_OWNERSHIP.md`](docs/FEATURE_OWNERSHIP.md):

| Feature Slice | Package | Status | Endpoints / Scope | PRD Ref |
|---|---|---|---|---|
| **Auth & Accounts** | `features/auth` | ✅ Done | `/auth/register`, `/auth/verify-email{,/resend}`, `/auth/login`, `/auth/refresh`, `/auth/password-reset/{request,confirm}`, `DELETE /auth/account` | §6.1 |
| **Brand Kit** | `features/brandkit` | ✅ Done | `GET/PUT /brand-kits/{id}` (owner-scoped idempotent upsert) | §6.8 |
| **Assets & Hardening** | `features/asset` | ✅ Done | `POST /assets` (magic-byte validation, dimension bounds, pixel re-encoding stripping EXIF/polyglots, stored off-web-root) | §6.8, §7.8 |
| **Admin Portal** | `features/admin` | ✅ Done | `/admin/usage`, `/admin/flags`, `/admin/flags/{id}/review`, `/admin/users/{id}/limits` (transactional audit logging, role-gated) | §6.13 |
| **Moderation** | `features/moderation` | 🔒 Internal | Pre-generation gate (`Checker`). Stubs and **fails closed** (blocks generation) to prevent unmoderated leakage before provider integration. | §6.4 |
| **Text Generation** | `features/generation` + `hashtag` | 🟡 Stub | `POST /generate/text` (compiles; returns 501 `not_implemented`) | §6.2, §6.3 |
| **Image Generation** | `features/generation` | 🟡 Stub | `POST /generate/image` (compiles; enforces 1:1 and 4:5 ratios, rejects 9:16; returns 501) | §6.5 |
| **Video Generation & Worker** | `features/generation` + `cmd/worker` | 🟡 Stub | `POST /generate/video`, `GET /jobs/{id}` (compiles; async queue contract ready; returns 501) | §6.5, §8.4, §10.3 |
| **Quota & Abuse Control** | `features/quota` | 🟡 Stub | `GET /quota/me` + pre-call enforcement hook (compiles; returns 501) | §6.14, §12 |
| **Reminders** | `features/reminder` | 🟡 Stub | `POST /reminders` (compiles; UTC timestamps, opaque client draft IDs; returns 501) | §6.12 |

---

## Quickstart

Requires Go 1.25+ and Docker (for local Postgres). Module path is `github.com/Bereke1t2/KELAL-STUDIO/backend`.

```bash
cd backend
make tidy                 # resolve deps + write go.sum (do this first, after clone)
cp .env.example .env      # local config; .env is gitignored — never commit secrets
```

### Option A — no database (mock mode)

Runs the whole backend on in-memory repositories. The fastest way to boot and hit the API; the analogue of the mobile app's mock data layer.

```bash
USE_MOCK_DATA=true make run
# API on http://localhost:8080  (health: GET /healthz)
```

### Option B — real Postgres

```bash
make db-up                # start Postgres in the background (docker compose)
make migrate              # apply the schema (AutoMigrate via `-migrate-only`)
make run                  # API on http://localhost:8080
```

### Try the reference feature (Auth)

```bash
# register → returns access_token + refresh_token
curl -s localhost:8080/v1/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"owner@example.com","password":"supersecret"}'

# login
curl -s localhost:8080/v1/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"owner@example.com","password":"supersecret"}'

# a stub endpoint returns a taxonomy-shaped 501 (needs a bearer token)
curl -s localhost:8080/v1/quota/me -H 'authorization: Bearer <access_token>'
# → {"error_code":"not_implemented","message":"... is not implemented yet."}
```

### Browse the API docs

Outside production the server renders the OpenAPI contract as interactive Swagger UI — open <http://localhost:8080/docs> (raw spec at `/openapi.yaml`). "Try it out" calls the running server directly; both routes are gated on `APP_ENV` and are never served when `APP_ENV=production`.

---

## Everyday Commands

`make help` lists all available targets. Commonly used commands:

| Command | What it does |
|---|---|
| `make check` | The full local gate: `gofmt` check → `go vet` → tests (**run before every commit** — mirrors CI) |
| `make test` | Runs tests with the race detector and coverage (`-race -cover`) |
| `make fmt` | Formats all Go source files in place |
| `make lint` | Runs `golangci-lint run` (configured in `.golangci.yml`) |
| `make build` | Compiles `api` and `worker` binaries into `bin/` |
| `make run` | Runs the API server (`cmd/api/main.go`) on port 8080 |
| `make worker` | Runs the asynchronous video job worker (`cmd/worker/main.go`) |
| `make migrate` | Applies database schema migrations and exits |
| `make db-up` | Starts local PostgreSQL container via Docker Compose |
| `make db-down` | Stops the local PostgreSQL container |
| `make tidy` | Resolves dependencies and writes `go.sum` |
| `make clean` | Removes compiled binaries and coverage output |

---

## Configuration

Every setting comes from the environment through one typed, validated struct (`internal/platform/config`). `.env.example` documents every key. Highlights:

- `USE_MOCK_DATA` — `true` runs entirely on in-memory repos (no Postgres needed).
- `APP_ENV` — `development` or `production`. When set to `production`, the server refuses to boot with dev JWT secrets, mock data enabled, or the `log` email provider.
- `HTTP_PORT` — Defaults to `8080` (binds to all interfaces).
- `DATABASE_URL` — PostgreSQL connection string (takes precedence over separate `DB_*` variables; ignored when `USE_MOCK_DATA=true`).
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` — Cryptographic secrets for signing session tokens (required in production).
- `EMAIL_PROVIDER` — `log` (writes verification/reset tokens to console for dev) or `smtp` (requires `EMAIL_SMTP_*`).
- `RATE_LIMIT_PER_MINUTE` / `RATE_LIMIT_IP_PER_MINUTE` — In-memory rate limiting for authenticated users and client IPs.
- `MODERATION_PROVIDER` — `stub` (fails closed, refusing content) or `openai` (requires `OPENAI_API_KEY`).
- `TEXT_PROVIDER_ORDER` / `IMAGE_PROVIDER_ORDER` / `VIDEO_PROVIDER_ORDER` — Comma-separated failover chains (e.g., `gemini,stub`).
- `QUEUE_DRIVER` — Defaults to `inproc` (in-process channel queue).
- `ASSET_STORAGE_DIR` / `ASSET_MAX_BYTES` — Directory for uploaded image storage (stored outside web root) and maximum allowed payload size.
- **Provider keys are server-side only.** No AI-provider credential ever reaches the mobile client (PRD §7.8, §10.1). The app ships with `stub` providers (OQ-20) until a model is chosen.

---

## Project Layout

```
backend/
├── api/openapi.yaml          # canonical HTTP contract (source of truth)
├── cmd/
│   ├── api/main.go           # composition root: config → DB → wire features → serve
│   └── worker/main.go        # async video worker (idles on the in-proc queue; §10.3)
├── migrations/               # golang-migrate SQL (production schema path)
├── docs/                     # ARCHITECTURE · FEATURE_OWNERSHIP · OPEN_QUESTIONS
└── internal/
    ├── platform/             # the "common things": config, database, httpx(+middleware),
    │                         #   apidocs, apperror, auth, provider, queue, logger, validate
    ├── models/               # every GORM entity (one shared schema)
    └── features/
        ├── auth/             # ★ reference feature — fully implemented + tested
        ├── brandkit/         # implemented + tested (owner-scoped brand-kit CRUD)
        ├── asset/            # implemented + tested (hardened upload & pixel re-encoding)
        ├── admin/            # implemented + tested (usage metrics, moderation flags, user limits)
        └── generation/ moderation/
            quota/ hashtag/ reminder/   # compiling stubs
```

---

## Adding a Feature (Copy `auth/`)

`auth/` is the proven template. To add a slice:

1. `cp -r internal/features/auth internal/features/<name>` and gut the bodies.
2. Define the port in `domain.go`; write one use case per method in `service.go` (returns `(T, *apperror.Error)` — never panic).
3. Implement `repository.go` (GORM) **and** `repository_mock.go` (in-memory).
4. Match `dto.go` to your operation's shapes in `api/openapi.yaml`.
5. Add **one** wiring line in `cmd/api/main.go`.
6. Copy `auth/`'s `service_test.go` + `handler_test.go` and adapt.
7. `make check` green, then commit via `/commit`.

The rules that keep this parallelizable (full detail in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)):

- **Features never import each other.** Share only through `internal/platform/*` and `internal/models`.
- **No feature talks to an AI provider directly** — always through `internal/platform/provider`.
- **`domain.go`/`service.go` import no Gin or GORM.** Gin lives in `handler.go`/`routes.go`; GORM in `repository.go`.
- **Never silently resolve an open question** — flag it in code and in [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md), then stop.

---

## Contributing

Commits use Conventional Commits and go through `/commit` (a `PreToolUse` hook blocks a raw `git commit` on staged `backend/**` without a passing review marker). **Do not add an AI-attribution trailer** — repo rule. PRs are stacked via `/pr`. See the repo root [`CONTRIBUTING.md`](../CONTRIBUTING.md) and [`CLAUDE.md`](../CLAUDE.md).
