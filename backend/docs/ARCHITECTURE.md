# Backend Architecture

Feature-first Clean Architecture, adapted to idiomatic Go. This mirrors the
mobile team's mental model (`mobile/CLAUDE.md`) so the two halves of the product
share one way of thinking:

| Mobile (Flutter) | Backend (Go) |
|---|---|
| `lib/features/<name>/{data,domain,presentation}` | `internal/features/<name>/` (one package, role-named files) |
| `domain/` pure Dart | `domain.go` — no Gin, no GORM |
| one usecase class per action | one `service.go` method per use case |
| `Result<Failure, T>` (never throw) | `(T, *apperror.Error)` (return, never panic across a boundary) |
| mock/real datasource `@module`, gated on `Env.useMockApi` | `module.go`, gated on `cfg.UseMockData` |
| `core/` cross-cutting | `internal/platform/` cross-cutting |

## The dependency rule

```
delivery (handler/dto/routes) ─▶ service ─▶ Repository (port) ◀─ repository (GORM) / repository_mock (in-memory)
```

Dependencies point **inward**. The service depends only on interfaces
(`domain.go`), never on Gin or GORM. Interfaces are declared **consumer-side**
(in the feature that needs them), so a feature can be built, tested, and
reviewed against its port with no real database.

**Ironclad rules (enforced by review + the import graph):**

1. **`internal/features/*` packages never import each other.** Cross-feature
   reuse happens only through `internal/platform/*` and `internal/models`. If
   two features need the same logic, it belongs in `platform` or is a shared
   model. This is what lets one person own a whole feature with near-zero merge
   conflicts.
2. **`domain.go` and `service.go` import no web/ORM framework.** No `gin`, no
   `gorm`. Only `context`, `models`, `apperror`, `platform/*`, stdlib.
3. **Gin lives only in `handler.go` / `routes.go`. GORM lives only in
   `repository.go`.** The mock (`repository_mock.go`) imports neither.
4. **No feature talks to an AI provider directly** (PRD §1.1, §10.1). Every
   generation call goes through `internal/platform/provider` — the Provider
   Abstraction Layer — which owns the failover chain, per-provider timeout,
   telemetry, and the provider→`apperror` mapping. A feature depends on the
   `provider.TextProvider` / `provider.ImageProvider` interface, never a vendor.
5. **Every failure crossing a public API is an `*apperror.Error`** (the Go
   analogue of the sealed `Failure`). The delivery layer renders it to the
   contract's `ErrorResponse` shape via `httpx.Fail` — no per-feature type
   switch.

## A feature package (the `auth/` template)

Every feature is ONE Go package. Files are named by role, not stacked in
sub-packages — this keeps the whole slice in one directory for a single owner:

| File | Responsibility | May import |
|---|---|---|
| `domain.go` | Port interfaces (`Repository`, …) + small domain types + sentinel errors | `context`, `models`, stdlib |
| `service.go` | One method per use case; returns `(T, *apperror.Error)` | ports, `platform/*`, `models` |
| `repository.go` | GORM implementation of the port | `gorm`, `models` |
| `repository_mock.go` | In-memory implementation (mock mode + tests) | `models`, stdlib, `sync` |
| `dto.go` | Request/response structs + binding tags matching `api/openapi.yaml` | `gin` binding tags only |
| `handler.go` | Bind → validate → call service → `httpx.OK`/`httpx.Fail` | `gin`, `httpx`, `validate` |
| `routes.go` | `RegisterRoutes(r *gin.RouterGroup, mw middleware.Set)` | `gin`, `middleware` |
| `module.go` | `New(deps) *Handler` — picks mock vs real repo by config, wires the service | everything above |
| `*_test.go` | Service unit tests over the mock + `httptest` handler tests | stdlib `testing` |

`module.go` is the seam. `New` selects the datasource exactly like a mobile
`@module`:

```go
var repo Repository
if d.Config.UseMockData || d.DB == nil {
    repo = NewMockRepository()
} else {
    repo = NewGormRepository(d.DB)
}
```

## The "common things" — `internal/platform/`

Cross-cutting infrastructure with **zero business logic**. This is what lands
first so feature teams can build in parallel:

| Package | What it provides |
|---|---|
| `config` | The single door for `os.Getenv` → one typed, validated `Config`. Refuses dev JWT secrets in production. |
| `database` | GORM connection + pool tuning (`Connect`) and `AutoMigrate` (dev/V1 schema). |
| `httpx` | JSON response writers (`OK`/`Created`/`Accepted`/`Fail`) + `NewRouter`. Imports only `apperror` + `gin` — **never** middleware or features (no cycle). |
| `httpx/middleware` | `RequestID`, `Logger`, `Recover`, `CORS`, `IPRateLimit`, `Auth`, `AdminOnly`, `UserRateLimit`, and the `Set` features receive. |
| `apidocs` | Serves the embedded `api/openapi.yaml` and an interactive Swagger UI at `/docs` (non-production only). Mounted from `cmd/api`, not `httpx`, so `httpx` keeps its apperror+gin-only imports. |
| `apperror` | The typed error taxonomy (`Error{Code, Message, HTTPStatus, ResetsAt}`) + constructors. |
| `auth` | JWT sign/verify (access + refresh + purpose-bound reset) and bcrypt password hashing. Imported as `platformauth` in `cmd/api` to avoid colliding with the `auth` feature. |
| `provider` | The Provider Abstraction Layer: `TextProvider`/`ImageProvider` interfaces, the ordered failover `chain`, provider→`apperror` mapping, a `factory` that builds chains from config, and deterministic `stub` providers (OQ-20). |
| `queue` | `Queue` interface + `Job` + an in-process implementation (`inproc`). §10.3 flagged. |
| `logger` | `slog` construction from the configured level. |
| `validate` | Request-binding/validation helpers (`BindJSON`) mapping validator errors to `apperror.Validation`. |

## `internal/models/` — one shared schema

All GORM entities live in one package that imports nothing internal. Rationale
and the persistence-coupling tradeoff are documented at the top of
`internal/models/base.go`. `models.All()` lists every entity in dependency
order for `AutoMigrate`; add new models there.

**Two schema paths, kept in sync:**
- **`AutoMigrate`** (`database.AutoMigrate`, driven by `models.All()`) — used for
  local dev and non-production, and by `make migrate` (`go run ./cmd/api
  -migrate-only`).
- **`migrations/*.sql`** (golang-migrate) — the production path. Column types and
  index names are written to match GORM's defaults so both converge on identical
  objects. Which one becomes authoritative is a flagged open item
  (`docs/OPEN_QUESTIONS.md`, schema-authority).

## Composition root — `cmd/api/main.go`

The ONE place that reads config, dials the DB, builds the shared singletons, and
wires every feature onto the `/v1` group. Adding a feature is one line here:

```go
auth.New(auth.Deps{DB: db, JWT: jwtMgr, Config: cfg, Logger: log}).RegisterRoutes(v1, mw)
brandkit.New().RegisterRoutes(v1, mw)
// …
```

`cmd/worker/main.go` is the async video consumer shape (§8.4, §10.3) — it idles
on the in-process queue today (flagged).

## How to add a feature

1. `cp -r internal/features/auth internal/features/<name>` and gut the bodies.
2. Define your port in `domain.go`, use cases in `service.go`.
3. Implement `repository.go` (GORM) + `repository_mock.go` (in-memory).
4. Match `dto.go` to your operation's shapes in `api/openapi.yaml`.
5. Add one wiring line to `cmd/api/main.go`.
6. Write `service_test.go` + `handler_test.go` against the mock (copy auth's).
7. `make check` (fmt + vet + test) must be green; commit via `/commit`.

See `README.md` for the quickstart and `docs/FEATURE_OWNERSHIP.md` for who owns
what.
