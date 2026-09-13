# Kelal Studio (ቀላል ስቱዲዮ)

[![Status](https://img.shields.io/badge/status-in%20development-orange?style=flat-square)](#roadmap--current-status)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Go](https://img.shields.io/badge/Go-00ADD8?style=flat-square&logo=go&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=flat-square&logo=react&logoColor=61DAFB)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=flat-square&logo=typescript&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)

> **Bilingual (Amharic/English) AI content-generation platform tailored for Ethiopian small businesses and creators.**

Ethiopian small businesses and merchants face a persistent challenge in digital commerce: crafting consistent, high-impact marketing copy and visuals in both Amharic and English without the overhead of dedicated design agencies. **Kelal Studio** bridges this gap directly on mobile. Small business owners can compose an idea, generate contextual captions and culturally resonant visuals, refine them on an interactive canvas, and export polished marketing collateral in seconds.

For full architectural requirements, user personas, and product specifications, see the [Product Requirements Document (PRD)](docs/Kelal_Studio_PRD.pdf).

---

## Table of Contents

- [Monorepo Architecture](#monorepo-architecture)
- [Feature Status](#feature-status)
- [Screenshots & Visuals](#screenshots--visuals)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [1. Backend (Go API)](#1-backend-go-api)
  - [2. Mobile App (Flutter)](#2-mobile-app-flutter)
  - [3. Web Portal (React)](#3-web-portal-react)
  - [Running Against Real Postgres & Providers](#running-against-real-postgres--providers)
- [Environment & Security Architecture](#environment--security-architecture)
- [Hosting & Production Deployment](#hosting--production-deployment)
- [Roadmap & Current Status](#roadmap--current-status)
- [Contributing](#contributing)
- [Author](#author)

---

## Monorepo Architecture

Kelal Studio is organized as a multi-package monorepo separating mobile delivery, backend logic, web administration, and product documentation:

| Package | Purpose | Stack | Status | Documentation |
|---|---|---|---|---|
| [`mobile/`](mobile/) | Primary client application for iOS & Android | Flutter 3 · Dart · BLoC · Clean Architecture | **Built** (P0 feature set) | [`mobile/README.md`](mobile/README.md) |
| [`backend/`](backend/) | Central REST API & asynchronous job worker | Go 1.25 · Gin · GORM · PostgreSQL | **Active** (Core slices complete; AI stubs) | [`backend/README.md`](backend/README.md) |
| [`web/`](web/) | Management portal for Brand Kit & Admin oversight | React 19 · TypeScript · Vite · Tailwind CSS 4 | **In Progress** (Foundation & shell active) | [`web/README.md`](web/README.md) |
| [`docs/`](docs/) | Product specifications and architectural references | Markdown · PDF | **Reference** | [`docs/Kelal_Studio_PRD.pdf`](docs/Kelal_Studio_PRD.pdf) |

> [!NOTE]
> Deep architectural guides, package-specific conventions, and testing commands live in each package's respective `README.md` and `CLAUDE.md`. This root document provides end-to-end orchestration across the entire stack.

---

## Feature Status

Implementation progress across the platform is tracked through backend feature contracts ([`backend/docs/FEATURE_OWNERSHIP.md`](backend/docs/FEATURE_OWNERSHIP.md)) and mobile architectural boundaries:

### Backend Slices

| Feature / Domain | Status | Description & Endpoints |
|---|---|---|
| **Auth & Accounts** | ✅ Done | Email verification flow (`POST /auth/verify-email`), registration, JWT login, token refresh, password resets, and account deletion (`DELETE /auth/account`). |
| **Brand Kit** | ✅ Done | Owner-scoped, idempotent upsert (`GET/PUT /brand-kits/{id}`) storing brand colors, typography, tone of voice, and logo references. |
| **Asset Pipeline** | ✅ Done | Hardened upload (`POST /assets`): validates magic bytes (JPEG/PNG only), enforces dimension bounds, re-encodes raw pixels to purge EXIF/metadata/polyglots, and stores off-web-root. |
| **Admin Oversight** | ✅ Done | Role-gated (`mw.AdminOnly`) usage analytics, prompt flag moderation queue, review resolutions, and transactional audit logging (`/admin/*`). |
| **Moderation Engine** | 🔒 Internal | Pre-generation gate (`Checker`). Currently stubs and **fails closed** (blocks generation) to prevent unmoderated output leaks prior to provider integration. |
| **Text Generation** | 🟡 Stub | `POST /generate/text` — route mounted and schema-compliant; returns structured `501 Not Implemented` pending provider selection. |
| **Image Generation** | 🟡 Stub | `POST /generate/image` — enforces aspect ratios `1:1` and `4:5` (rejects `9:16`); returns `501 Not Implemented`. |
| **Video Generation & Worker** | 🟡 Stub | `POST /generate/video` & `GET /jobs/{id}` — async queue contract ready; backed by `cmd/worker` process. |
| **Quota & Rate Limiting** | 🟡 Stub | `GET /quota/me` — schema mounted; pre-call enforcement hook stubs to 501. |
| **Reminders** | 🟡 Stub | `POST /reminders` — scheduled UTC notifications with opaque client draft references. |

### Mobile Client (`mobile/`)
- **P0 Mobile Surface**: Feature-first Clean Architecture (`features/<name>/{data,domain,presentation}`).
- **Single Canvas Render Engine**: Shared canvas paint routine (`core/render_engine`) used identically in interactive editing and final raster export, structurally eliminating preview-to-export discrepancies.
- **In-App Brand Kit**: Standalone configuration screen (`/brand`) providing real-time color palettes, logo assignment, and live preview rendering.
- **Built-in Mock API**: Fully functional offline/local development mode (`Env.useMockApi = true`) decoupled from backend availability.
- **Bilingual Interface**: Native Amharic and English localization (`lib/core/l10n/gen/`).

### Web Portal (`web/`)
- **Scoped Surface**: Dedicated strictly to Brand Kit management and admin moderation oversight (PRD §4). Content generation is intentionally omitted from web.
- **Foundation**: Built on React 19, TypeScript, and Vite with a typed OpenAPI client, automatic token refresh, and CSS design tokens derived from Figma.

---

## Screenshots & Visuals

> [!NOTE]
> *Screenshots coming soon.*
> High-fidelity mobile screen recordings and web portal captures are currently being updated to reflect the latest UI system. Placeholder images are omitted to maintain visual accuracy.

---

## Getting Started

To spin up the complete platform locally from a clean clone, open three terminal sessions: one for the backend, and the others for mobile and/or web.

### Prerequisites

- **Go**: `1.25+`
- **Docker & Docker Compose**: For local PostgreSQL
- **Flutter**: `3.x` (managed via [FVM](https://fvm.app/) recommended; see `.fvmrc`)
- **Node.js**: `20+` and `npm`

---

### 1. Backend (Go API)

```bash
cd backend

# 1. Resolve Go dependencies (first run only)
make tidy

# 2. Configure local environment
cp .env.example .env

# 3. Boot with in-memory mock data (fastest start, no DB required)
USE_MOCK_DATA=true make run
```

- **Base URL**: `http://localhost:8080`
- **Health Check**: `curl http://localhost:8080/healthz`
- **Interactive Swagger UI**: `http://localhost:8080/docs` (available in non-production mode)

*For persistent PostgreSQL setup instructions, see [Running Against Real Postgres & Providers](#running-against-real-postgres--providers).*

---

### 2. Mobile App (Flutter)

The mobile client defaults to in-app mock repositories (`USE_MOCK_API=true`), running completely standalone without an active backend. To point it at your local Go API:

```bash
cd mobile

# 1. Install dependencies & run code generation
fvm flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Run on target device/emulator connected to local backend
fvm flutter run \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=http://localhost:8080/v1
```

> [!IMPORTANT]
> **The trailing `/v1` is strictly required**: The backend mounts all routes under `/v1`, but mobile endpoint paths (`/auth/login`, etc.) do not include this prefix. `API_BASE_URL` must supply it.

#### Target-Specific Network Configuration

- **iOS Simulator**: Use `http://localhost:8080/v1`.
- **Android Emulator**: The Android emulator treats `localhost` as itself. Use **`http://10.0.2.2:8080/v1`**.
- **Physical Device**: Connect your phone to the same Wi-Fi network as your workstation and use your LAN IP (e.g., `http://192.168.1.50:8080/v1`). The backend binds to all interfaces by default.

---

### 3. Web Portal (React)

```bash
cd web

# 1. Install packages
npm ci

# 2. Launch Vite development server
npm run dev
```

- **Local URL**: `http://localhost:5173`
- The Vite dev server automatically proxies `/v1` requests to `http://localhost:8080`. Override the proxy target with `VITE_API_TARGET` if running the backend on an alternate port.

---

### Running Against Real Postgres & Providers

When you are ready to test end-to-end persistence with real database migrations:

1. **Start Database & Run Migrations**:
   ```bash
   cd backend
   make db-up       # Launches PostgreSQL container
   make migrate     # Applies database schema migrations
   ```
2. **Configure `.env`**:
   In `backend/.env`, set:
   ```ini
   USE_MOCK_DATA=false
   DATABASE_URL=postgres://postgres:postgres@localhost:5432/kelal_studio?sslmode=disable
   ```
   To test generative features with live models, supply server credentials (e.g., `GEMINI_API_KEY`) and activate provider order:
   ```ini
   TEXT_PROVIDER_ORDER=gemini
   IMAGE_PROVIDER_ORDER=gemini
   ```
3. **Run Backend**:
   ```bash
   make run
   ```
4. **Connect Clients**:
   Launch mobile and web as shown in the quickstart above.

> [!TIP]
> When testing against a real database for the first time, walk through the core flows manually: register → email verification → login → brand kit save & logo upload → caption & graphic generation.

---

## Environment & Security Architecture

**Only the backend holds environment secrets. Mobile and web clients never hold API credentials.**

This architecture is intentional (PRD §7.8, §10.1). Mobile application binaries (APKs/IPAs) and compiled JavaScript single-page application bundles are deployed to untrusted user devices where embedded strings and keys can be trivially extracted.

```
┌─────────────────────────────────────────────────────────────┐
│                       Client Tier                           │
│  ┌─────────────────────────┐   ┌─────────────────────────┐  │
│  │     Flutter Mobile      │   │       React Web         │  │
│  │   No secrets / .env     │   │   No secrets / .env     │  │
│  │   --dart-define target  │   │   Vite dev proxy target │  │
│  └────────────┬────────────┘   └────────────┬────────────┘  │
└───────────────┼─────────────────────────────┼───────────────┘
                │ HTTP / JSON                 │ HTTP / JSON
                ▼                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Go Backend (API Gateway)                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  backend/.env (Strictly Server-Side)                  │  │
│  │  • JWT Signing Secrets (Access & Refresh)             │  │
│  │  • PostgreSQL Connection Strings                      │  │
│  │  • SMTP / Mailer Credentials                          │  │
│  │  • AI Provider Keys (Gemini, OpenAI, etc.)            │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Backend Credentials Summary (`backend/.env`)

- **`JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`**: Cryptographic secrets for signing session tokens. The server halts on boot if default values are used with `APP_ENV=production`.
- **`DATABASE_URL`**: PostgreSQL connection string (ignored when `USE_MOCK_DATA=true`).
- **`EMAIL_PROVIDER`**: Set to `log` for local development (prints verification and reset tokens directly to stdout). In production, set to `smtp` with matching `EMAIL_SMTP_*` parameters.
- **`TEXT_PROVIDER_ORDER` / `IMAGE_PROVIDER_ORDER` / `VIDEO_PROVIDER_ORDER`**: Selects provider chains (e.g., `gemini`, `openai`, or `stub`). Keys are stored solely in this file.
- **`MODERATION_PROVIDER`**: Defaults to `stub` (fails closed). Set to `openai` alongside `OPENAI_API_KEY` for active content screening.

---

## Hosting & Production Deployment

The repository is cloud-agnostic and does not hardwire a specific vendor deployment pipeline:

- **Backend**:
  - A production container is built using `backend/Dockerfile`.
  - Alternatively, `make build` compiles native binaries for `api` and `worker`.
  - **Worker Process**: In addition to `bin/api`, `cmd/worker` (`bin/worker`) must run as a distinct continuous process to drain background video generation jobs.
  - In production (`APP_ENV=production`), the binary enforces valid production secrets, HTTPS termination, and active database migrations.
- **Web Portal**:
  - `npm run build` generates a static SPA bundle in `web/dist/`.
  - The frontend is designed to be served **same-origin** behind a reverse proxy (such as Nginx, Cloudflare, or Caddy) that forwards `/v1/*` to the Go API and serves the static HTML/JS assets.
- **Mobile Client**:
  - Production builds require release signing keystores/certificates configured in `mobile/android/app/build.gradle.kts` and Xcode.
  - Point release builds at your production endpoint:
    ```bash
    fvm flutter build apk --release \
      --dart-define=USE_MOCK_API=false \
      --dart-define=API_BASE_URL=https://api.yourdomain.com/v1
    ```

---

## Roadmap & Current Status

The project is under active development. Core product and engineering questions being tracked across the repository:

- [ ] **AI Provider Selection (OQ-20)**: Finalize primary LLM and image generation partner contracts (Gemini vs OpenAI) to replace the current deterministic mock provider layer.
- [ ] **Distributed Queue Driver (§10.3)**: Implement a distributed broker driver (Redis or SQS) behind `queue.Queue` so that the `api` and `cmd/worker` services can share async video jobs across distributed instances.
- [ ] **Aspect Ratio Ratification (OQ-02)**: Expand image generation dimensions beyond the current supported `1:1` and `4:5` set once product confirmation is reached.
- [ ] **Draft Sync Strategy (OQ-05)**: Evaluate server-side draft synchronization versus V1's offline device-local draft model.
- [ ] **Prompt Privacy & Retention (OQ-13/19)**: Establish formal data residency and prompt retention policies for Ethiopian business data before public beta.
- [ ] **Mobile Store Sign-Off**: Complete Android keystore and Apple Developer provisioning profiles for store deployment.
- [ ] **Web Portal Completion**: Merge stacked feature branches for Amharic/English internationalization, Brand Kit editing forms, and admin dashboards.

---

## Contributing

We welcome contributions! Please review [`CONTRIBUTING.md`](CONTRIBUTING.md) for detailed guidelines.

### Summary of Repository Standards:
- **Conventional Commits**: Format commit messages as `feat:`, `fix:`, `refactor:`, `chore:`, or `test:`, focusing on *why* a change was made.
- **Stacked Pull Requests**: Multi-part changes are structured using [`gh stack`](https://gh.io/stacks) rather than massive monolithic PRs.
- **Mobile Quality Gate**: Changes to `mobile/` must pass formatting, static analysis, unit tests, and review checks via `/commit` (`mobile/.claude/commands/commit.md`).
- **No AI Attribution Trailers**: Do not append auto-generated AI authoring tags to commit messages.

---

## Author

**Zaferan**  
Software Engineering Student at Adama Science and Technology University (ASTU)  
GitHub: [@Zaf-Mif](https://github.com/Zaf-Mif)
