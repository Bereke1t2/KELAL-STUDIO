# Kelal Studio — Backend (Go API)

The Go API for Kelal Studio, a bilingual (Amharic/English) AI content-generation
app for Ethiopian businesses. Built in **feature-first Clean Architecture** so a
team can split into feature slices and work in parallel from day one.

- **Stack:** Go 1.25 · Gin · GORM · PostgreSQL · JWT · slog
- **Spec:** [`api/openapi.yaml`](api/openapi.yaml) is the source of truth for the
  HTTP contract. The PRD is `../docs/Kelal_Studio_PRD.pdf`.
- **Read next:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (layering + rules),
  [`docs/FEATURE_OWNERSHIP.md`](docs/FEATURE_OWNERSHIP.md) (who owns what),
  [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md) (flagged, do-not-resolve
  items).

The **Auth** feature is the fully-worked reference every other slice copies, and
**Brand Kit** is the second implemented slice (owner-scoped `GET`/`PUT`, built by
copying auth). Every remaining feature is a compiling stub that returns a
structured `not_implemented` (501) error, so the app boots and the mobile team
can integrate against real error shapes today.

## Quickstart

Requires Go 1.25+ and Docker (for local Postgres). Module path is
`github.com/Bereke1t2/KELAL-STUDIO/backend`.

```bash
cd backend
make tidy                 # resolve deps + write go.sum (do this first, after clone)
cp .env.example .env      # local config; .env is gitignored — never commit secrets
```

### Option A — no database (mock mode)

Runs the whole backend on in-memory repositories. The fastest way to boot and
hit the API; the analogue of the mobile app's mock data layer.

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

## Everyday commands

`make help` lists them all. The ones you'll use:

| Command | What it does |
|---|---|
| `make check` | The full local gate: `gofmt` check → `go vet` → tests (**run before every commit** — mirrors CI) |
| `make test` | Tests with the race detector + coverage |
| `make fmt` | Format all Go in place |
| `make lint` | `golangci-lint run` (see `.golangci.yml`) |
| `make build` | Compile `api` + `worker` into `bin/` |
| `make run` / `make worker` | Run the API / the async video worker |
| `make migrate` | Apply DB migrations, then exit |
| `make db-up` / `make db-down` | Start / stop local Postgres |

## Configuration

Every setting comes from the environment through one typed, validated struct
(`internal/platform/config`). `.env.example` documents every key. Highlights:

- `USE_MOCK_DATA` — `true` runs on in-memory repos (no Postgres).
- `APP_ENV` — `production` refuses to boot with the dev JWT secrets or with mock
  data on.
- **Provider keys are server-side only.** No AI-provider credential ever reaches
  the mobile client (PRD §7.8, §10.1). The app ships with `stub` providers
  (OQ-20) until a model is chosen.

## Project layout

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
    │                         #   apperror, auth, provider, queue, logger, validate
    ├── models/               # every GORM entity (one shared schema)
    └── features/
        ├── auth/             # ★ reference feature — fully implemented + tested
        ├── brandkit/         # implemented + tested (owner-scoped brand-kit CRUD)
        └── asset/ generation/ moderation/
            quota/ hashtag/ reminder/ admin/   # compiling stubs
```

## Adding a feature (copy `auth/`)

`auth/` is the proven template. To add a slice:

1. `cp -r internal/features/auth internal/features/<name>` and gut the bodies.
2. Define the port in `domain.go`; write one use case per method in `service.go`
   (returns `(T, *apperror.Error)` — never throw).
3. Implement `repository.go` (GORM) **and** `repository_mock.go` (in-memory).
4. Match `dto.go` to your operation's shapes in `api/openapi.yaml`.
5. Add **one** wiring line in `cmd/api/main.go`.
6. Copy `auth/`'s `service_test.go` + `handler_test.go` and adapt.
7. `make check` green, then commit via `/commit`.

The rules that keep this parallelizable (full detail in `docs/ARCHITECTURE.md`):

- **Features never import each other.** Share only through `internal/platform/*`
  and `internal/models`.
- **No feature talks to an AI provider directly** — always through
  `internal/platform/provider`.
- **`domain.go`/`service.go` import no Gin or GORM.** Gin lives in
  `handler.go`/`routes.go`; GORM in `repository.go`.
- **Never silently resolve an open question** — flag it in code and in
  `docs/OPEN_QUESTIONS.md`, then stop.

## Contributing

Commits use Conventional Commits and go through `/commit` (a `PreToolUse` hook
blocks a raw `git commit` on staged `backend/**` without a passing review
marker). **Do not add an AI-attribution trailer** — repo rule. PRs are stacked
via `/pr`. See the repo root `CONTRIBUTING.md` and `CLAUDE.md`.
