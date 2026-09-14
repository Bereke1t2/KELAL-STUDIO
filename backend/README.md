# Kelal Studio — Backend (Go API)

<!-- Badges Section Placeholder -->
[![Go](https://img.shields.io/badge/Go-1.25-00ADD8?logo=go&logoColor=white)](#)
[![Framework](https://img.shields.io/badge/Framework-Gin-008ECF)](#)
[![ORM](https://img.shields.io/badge/ORM-GORM-blue)](#)
[![Database](https://img.shields.io/badge/Database-PostgreSQL%2016-336791?logo=postgresql&logoColor=white)](#)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-3.0-green?logo=openapi-initiative&logoColor=white)](#)
[![CI](https://img.shields.io/badge/CI-Passing-brightgreen)](#)

The backend REST API powering Kelal Studio, a bilingual (Amharic/English) social media content generation platform for Ethiopian businesses.

---

## Table of Contents

- [Overview & Architecture](#overview--architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Setup & Quickstart](#setup--quickstart)
  - [1. Clone & Dependencies](#1-clone--dependencies)
  - [2. Environment Configuration](#2-environment-configuration)
  - [3. Option A — In-Memory Mock Mode (Fastest)](#3-option-a--in-memory-mock-mode-fastest)
  - [4. Option B — Real PostgreSQL Database](#4-option-b--real-postgresql-database)
  - [5. Verify Reference Endpoints](#5-verify-reference-endpoints)
- [API Documentation](#api-documentation)
- [Feature Status](#feature-status)
- [Project Structure](#project-structure)
- [Everyday Commands & Testing](#everyday-commands--testing)
- [Deployment & Production Notes](#deployment--production-notes)
- [Contributing & Workflow](#contributing--workflow)

---

## Overview & Architecture

The Kelal Studio API is architected around **Feature-First Clean Architecture**. Business logic is partitioned into modular, self-contained feature slices under `internal/features/` so independent product slices can be developed and reviewed in parallel without cross-package entanglement.

- **Reference Implementation**: The `auth` feature serves as the fully implemented, end-to-end reference slice.
- **Contract-First**: The HTTP specification in `api/openapi.yaml` is the canonical source of truth for all routes, request bodies, and error taxonomy shapes.
- **Fail-Closed Stubs**: Unimplemented slices compile as functional stubs returning structured `not_implemented` (501) errors matching the OpenAPI schema, allowing mobile and web clients to integrate against real contract shapes on day one.

---

## Tech Stack

| Component | Technology | Version | Purpose |
|---|---|---|---|
| **Language** | Go | `1.25.0` | High-concurrency backend runtime |
| **HTTP Framework** | Gin (`gin-gonic/gin`) | `v1.10.1` | High-performance HTTP router and middleware engine |
| **ORM** | GORM (`gorm.io/gorm`) | `v1.25.12` | Relational data persistence & migrations |
| **Database Driver** | PostgreSQL (`pgx/v5`) | `v1.5.11` / `v5.9.2` | Production-grade PostgreSQL connection pooling |
| **Authentication** | JWT (`golang-jwt/jwt/v5`) | `v5.2.2` | Stateless HS256 access and refresh tokens |
| **Validation** | Validator (`go-playground/validator/v10`) | `v10.20.0` | Struct and payload contract validation |
| **API Docs** | Swagger UI (`swaggest/swgui`) | `v1.8.9` | Interactive in-browser API explorer |
| **Logging** | `log/slog` | Standard Library | Structured JSON and text logging |

---

## Prerequisites

Before setting up the service locally, ensure you have installed:

- **Go SDK**: `1.25+`
- **Docker & Docker Compose**: For launching local PostgreSQL instances
- **Make**: For executing build, test, and lifecycle targets
- **External AI Providers (Optional)**: Keys for Gemini (`GEMINI_API_KEY`) or OpenAI (`OPENAI_API_KEY`). The service defaults to deterministic mock stubs (`TEXT_PROVIDER_ORDER=stub`, `IMAGE_PROVIDER_ORDER=stub`), so external provider keys are not required for local development.

---

## Setup & Quickstart

### 1. Clone & Dependencies

```bash
git clone https://github.com/Bereke1t2/KELAL-STUDIO.git
cd KELAL-STUDIO/backend

# Download and verify dependencies
make tidy
```

### 2. Environment Configuration

Copy the documented environment template:

```bash
cp .env.example .env
```

> **Security Note**: `.env` is gitignored. In accordance with PRD §7.8 and §10.1, **all secret credentials and provider keys live exclusively on the backend**. Never commit secrets or expose them to client applications.

Key configuration flags in `.env`:
- `USE_MOCK_DATA`: Set to `true` for in-memory mock repositories, `false` for PostgreSQL.
- `APP_ENV`: `development` for local testing, `production` for live deployments (refuses boot if default JWT secrets are detected).
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`: Signing secrets for bearer tokens.

### 3. Option A — In-Memory Mock Mode (Fastest)

Run the backend without needing a running database. Repositories run entirely in memory:

```bash
USE_MOCK_DATA=true make run
```
- API server listens on: `http://localhost:8080`
- Health check: `curl http://localhost:8080/healthz`

### 4. Option B — Real PostgreSQL Database

To run against a real PostgreSQL instance:

```bash
# 1. Start local PostgreSQL via Docker Compose
make db-up

# 2. Run database migrations
make migrate

# 3. Start the API server with real storage (ensure USE_MOCK_DATA=false in .env)
make run
```

### 5. Verify Reference Endpoints

```bash
# Register a new merchant account (returns access_token & refresh_token)
curl -s -X POST http://localhost:8080/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"owner@example.com","password":"supersecretpassword"}'

# Login to retrieve new tokens
curl -s -X POST http://localhost:8080/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"owner@example.com","password":"supersecretpassword"}'

# Call an authenticated endpoint (returns taxonomy-shaped 501 for stubs)
curl -s -X GET http://localhost:8080/v1/quota/me \
  -H "Authorization: Bearer <access_token>"
```

---

## API Documentation

Outside production (`APP_ENV!=production`), the backend renders the canonical OpenAPI specification as an interactive Swagger UI:

- **Interactive API Docs**: `http://localhost:8080/docs`
- **Raw OpenAPI Spec**: `http://localhost:8080/openapi.yaml` (file located at `api/openapi.yaml`)

Both routes are guarded and disabled automatically when `APP_ENV=production`.

---

## Feature Status

Current slice implementation status tracked directly from [`docs/FEATURE_OWNERSHIP.md`](docs/FEATURE_OWNERSHIP.md):

| Feature Slice | Package | Status | Endpoints / Scope | PRD Ref |
|---|---|---|---|---|
| **Auth & Accounts** | `features/auth` | Done | `/auth/register`, `/auth/verify-email{,/resend}`, `/auth/login`, `/auth/refresh`, `/auth/password-reset/{request,confirm}`, `DELETE /auth/account` | §6.1 |
| **Brand Kit** | `features/brandkit` | Done | `GET/PUT /brand-kits/{id}` (owner-scoped idempotent upsert) | §6.8 |
| **Assets & Hardening** | `features/asset` | Done | `POST /assets` (magic-byte validation, dimension bounds, pixel re-encoding stripping EXIF/polyglots, stored off-web-root) | §6.8, §7.8 |
| **Admin Portal** | `features/admin` | Done | `/admin/usage`, `/admin/flags`, `/admin/flags/{id}/review`, `/admin/users/{id}/limits` (transactional audit logging, role-gated) | §6.13 |
| **Moderation** | `features/moderation` | Internal | Pre-generation gate (`Checker`). Stubs and fails closed (blocks generation) to prevent unmoderated leakage before provider integration. | §6.4 |
| **Text Generation** | `features/generation` + `hashtag` | Stub | `POST /generate/text` (compiles; returns 501 `not_implemented`) | §6.2, §6.3 |
| **Image Generation** | `features/generation` | Stub | `POST /generate/image` (compiles; enforces 1:1 and 4:5 ratios, rejects 9:16; returns 501) | §6.5 |
| **Video Generation & Worker** | `features/generation` + `cmd/worker` | Stub | `POST /generate/video`, `GET /jobs/{id}` (compiles; async queue contract ready; returns 501) | §6.5, §8.4, §10.3 |
| **Quota & Abuse Control** | `features/quota` | Stub | `GET /quota/me` + pre-call enforcement hook (compiles; returns 501) | §6.14, §12 |
| **Reminders** | `features/reminder` | Stub | `POST /reminders` (compiles; UTC timestamps, opaque client draft IDs; returns 501) | §6.12 |

---

## Project Structure

```
backend/
├── api/
│   └── openapi.yaml          # Canonical HTTP contract (source of truth)
├── cmd/
│   ├── api/main.go           # Composition root: config -> DB -> wire feature routes -> HTTP server
│   └── worker/main.go        # Async background worker process (drains video generation queue)
├── migrations/               # SQL migration files for production schema deployment
├── docs/                     # ARCHITECTURE.md, FEATURE_OWNERSHIP.md, OPEN_QUESTIONS.md
└── internal/
    ├── platform/             # Cross-cutting concerns: config, db, middleware, httpx, auth, logger
    ├── models/               # Shared GORM database entity models
    └── features/             # Domain feature slices (Feature-First Clean Architecture)
        ├── auth/             # Reference slice: authentication, verification, tokens
        ├── brandkit/         # Brand kit storage & management
        ├── asset/            # Hardened file upload and image re-encoding pipeline
        ├── admin/            # Usage metrics, moderation flag queue, user quota overrides
        ├── moderation/       # Content moderation gatekeeper
        ├── generation/       # Text/image/video AI generation handlers
        ├── hashtag/          # Amharic/English hashtag generation
        ├── quota/            # Rate limiting and quota checks
        └── reminder/         # Post scheduling reminder stubs
```

### Feature Slice Layout
Each feature slice under `internal/features/<name>` adheres to strict decoupling rules:
- `domain.go`: Domain interfaces and business models (no Gin or GORM imports).
- `service.go`: Business use-case implementation returning typed `*apperror.Error`.
- `repository.go`: Database operations using GORM.
- `repository_mock.go`: Thread-safe in-memory storage implementation for tests and mock mode.
- `handler.go` & `routes.go`: Gin HTTP routing, request binding, and response formatting.
- `dto.go`: Request/response structs reflecting `api/openapi.yaml`.

---

## Everyday Commands & Testing

Execute common developer workflows with `make`:

| Command | Description |
|---|---|
| `make check` | **Quality gate**: runs `gofmt` check, `go vet`, and tests (must pass before commit) |
| `make test` | Executes test suite with race detector and code coverage output |
| `make cover` | Opens HTML code coverage report in browser |
| `make fmt` | Formats all Go source files with `gofmt` |
| `make lint` | Runs `golangci-lint` according to `.golangci.yml` rules |
| `make build` | Compiles `api` and `worker` binaries into `bin/` |
| `make run` | Runs the API HTTP server locally |
| `make worker` | Runs the asynchronous background queue worker |
| `make migrate` | Applies pending database migrations |
| `make db-up` | Launches local PostgreSQL container via Docker Compose |
| `make db-down` | Tears down local PostgreSQL container |

---

## Deployment & Production Notes

### 1. Containerization
A multi-stage `Dockerfile` is provided for containerized deployments:
- **Build Stage**: Compiles a static Linux binary (`CGO_ENABLED=0`) with trimmed paths.
- **Runtime Stage**: Based on `gcr.io/distroless/static-debian12:nonroot` to guarantee minimal attack surface and rootless execution.

```bash
# Build the production container
docker build -t kelal-studio-api:latest .
```

### 2. Video Queue Worker
The video generation pipeline is asynchronous (PRD §8.4, §10.3). In production, run both:
1. `bin/api`: Handles incoming HTTP traffic.
2. `bin/worker`: Drains and processes asynchronous generation tasks from the background queue.

### 3. Production Hardening Checklist
- Ensure `APP_ENV=production` is set in the production environment.
- Override `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` with cryptographically secure 32+ character random strings.
- Set `EMAIL_PROVIDER=smtp` along with valid SMTP credentials (`EMAIL_PROVIDER=log` will abort startup in production).
- Run the API process behind a TLS-terminating reverse proxy (e.g. Caddy or Nginx).

---

## Contributing & Workflow

- **Slice Ownership**: Check [`docs/FEATURE_OWNERSHIP.md`](docs/FEATURE_OWNERSHIP.md) and claim an unclaimed slice by adding your name to the **Owner** column before starting work.
- **Commit Guard**: Commits adhere to the [Conventional Commits](https://www.conventionalcommits.org/) format and must be executed via `/commit` (`.claude/commands/commit.md`), which validates `make check` before allowing the commit.
- **No AI Attribution Trailers**: Do not append automated AI credit lines to commit messages.
- **Stacked PRs**: Branch workflows are managed via `gh stack` (`/pr`).
