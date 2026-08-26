# Feature Ownership & Task Division

This is the map for splitting the backend across a team. Each **slice** below is
independently ownable: it's a single `internal/features/<name>/` package (plus,
for a few, one shared `platform` dependency). Because features never import each
other (see `ARCHITECTURE.md`), two people on two slices should almost never touch
the same file.

Fill in the **Owner** column when you claim a slice. Claim by slice, not by file.

## Status legend

- ✅ **done** — implemented + tested (the reference).
- 🟡 **stub** — compiles, routes registered, returns `not_implemented` (501) in
  the taxonomy shape. The app boots and mobile can integrate against real error
  bodies now. Your job: make it real without changing the wiring pattern.
- 🔒 **internal** — no HTTP route; a seam another feature consumes.

## Land FIRST (foundational — unblocks everyone)

These are **already built** and are the shared ground every slice stands on. If
you change one, you affect everyone — review accordingly.

- `platform/config`, `platform/database`, `platform/httpx` (+ `middleware`),
  `platform/apperror`, `platform/auth`, `platform/logger`, `platform/validate`
- `internal/models` (the whole schema) + `migrations/`
- `platform/provider` (abstraction + stubs) and `platform/queue` — the contracts
  generation and video depend on
- `cmd/api/main.go` wiring, `docker-compose.yml`, `Makefile`, CI

## Parallel feature slices

| Slice | Package | Status | Endpoints | PRD | Owner |
|---|---|---|---|---|---|
| **Auth & Accounts** (reference) | `features/auth` | ✅ done | `/auth/register`, `/auth/verify-email{,/resend}`, `/auth/login`, `/auth/refresh`, `/auth/password-reset/{request,confirm}`, `DELETE /auth/account` | §6.1 | — |
| **Brand Kit** | `features/brandkit` | ✅ done | `GET/PUT /brand-kits/{id}` | §6.8 | — |
| **Assets / upload hardening** | `features/asset` | ✅ done | `POST /assets` | §6.8, §7.8 | — |
| **Text Generation** | `features/generation` + `features/hashtag` | 🟡 stub | `POST /generate/text` | §6.2, §6.3 | _unclaimed_ |
| **Image Generation** | `features/generation` | 🟡 stub | `POST /generate/image` | §6.5 | _unclaimed_ |
| **Video Generation + Worker** | `features/generation` + `cmd/worker` | 🟡 stub | `POST /generate/video`, `GET /jobs/{id}` | §6.5, §8.4, §10.3 | _unclaimed_ |
| **Moderation** | `features/moderation` | 🔒 internal | none (pre-generation gate) | §6.4 | _unclaimed_ |
| **Quota & Abuse Control** | `features/quota` | 🟡 stub | `GET /quota/me` + **pre-call enforcement** | §6.14, §12 | _unclaimed_ |
| **Reminders** | `features/reminder` | 🟡 stub | `POST /reminders` | §6.12 | _unclaimed_ |
| **Admin Portal** | `features/admin` | 🟡 stub | `/admin/usage`, `/admin/flags`, `/admin/flags/{id}/review`, `/admin/users/{id}/limits` | §6.13 | _unclaimed_ |

> **`generation` is shared by three slices** (text/image/video). This is the one
> package where coordination matters: split it by file (e.g. one owner per
> `text.go`/`image.go`/`video.go` service method) or sequence the work. Everything
> else is fully independent.

## Per-slice load-bearing notes

Read these before starting — they're the non-obvious parts and the traps.

- **Brand Kit** (done) — a kit can exist before a logo (`logo_asset_id`
  nullable). Both endpoints are authenticated and **owner-scoped**: another
  user's kit is a 404, never a 403 (no id enumeration). Since the contract has
  no create endpoint, `PUT` is an idempotent owner-scoped **upsert** (update or
  create-at-id) — flagged as `brandkit-creation` in `OPEN_QUESTIONS.md`, not
  silently resolved.
- **Assets** (done) — the **highest-risk untrusted-input surface** in the whole
  backend. The pipeline validates by content (magic bytes), not the extension or
  client `Content-Type`; accepts **JPEG and PNG only**; enforces the byte and
  min/max dimension limits from `AssetConfig` **before** the full decode; then
  **re-encodes** every image from its decoded pixels — which **strips all
  metadata** (EXIF/GPS/ICC) and neutralizes polyglots — and stores the bytes via
  `platform/storage` **outside any web root** (PRD §6.8, §7.8). Every rejection is
  a `validation_error` (400). Policy choices (formats, reject-vs-downscale,
  re-encode format family, 400-vs-413/415) are flagged as `asset-upload-policy`
  in `OPEN_QUESTIONS.md`, not silently resolved.
- **Text Generation** — go through `provider.TextProvider` via the chain; call
  `moderation.Checker` **before** the provider; merge the `hashtag.Bank` output;
  enforce quota **before** the outbound call. Defensive-parse provider output
  into `GenerateTextResponse` (`malformed_output` on failure).
- **Image Generation** — only `1:1` and `4:5` (OQ-02); reject `9:16`, don't add
  it. Persist the result as an `Asset` and return its id.
- **Video Generation + Worker** — async: enqueue a `Job`, return it `queued`
  (202). The worker (`cmd/worker`) drains the queue. Mind the `result_asset_id`
  vs `result_generation_id` divergence (see OPEN_QUESTIONS). The in-process queue
  shares no jobs across processes — a real broker is flagged.
- **Moderation** — internal `Checker`; the stub **fails closed** (refuses
  everything) on purpose, so wiring it prematurely can't ship unmoderated
  content. Map a refusal to `apperror.ModerationRefused` with a plain-language
  reason (never a raw classifier code).
- **Quota** — the read endpoint (`GET /quota/me`) is the easy half; the
  **load-bearing** half is enforcement: an upsert-and-check on
  `QuotaConsumption(user_id, period)` that runs **before** any provider call and
  returns `quota_exceeded` with `resets_at`. Coordinate with generation.
- **Reminders** — `scheduled_at_utc` is always UTC; `draft_local_id` is an
  **opaque** client string (drafts are device-local in V1, OQ-05) — never
  dereference it into a server row.
- **Admin** — every mutating endpoint MUST write an `AdminAuditLog` row. Gated by
  `mw.AuthRequired` **and** `mw.AdminOnly`.

## Definition of done for a slice

1. Service methods implemented; port unchanged or extended (never depend on
   another feature).
2. Real GORM repo **and** in-memory mock repo both implement the port.
3. DTOs match `api/openapi.yaml`; update that spec if the backend intentionally
   diverges (backend is source of truth — then note it in OPEN_QUESTIONS).
4. `service_test.go` + `handler_test.go` cover the happy path and the taxonomy
   error paths (copy `auth/`'s tests).
5. `make check` green. Commit via `/commit` (Conventional Commits, **no AI
   attribution trailer** — repo rule).
6. Flip the slice's `x-implementation-status` from `stub` to `implemented` in
   `api/openapi.yaml`, and its row here from 🟡 to ✅.
