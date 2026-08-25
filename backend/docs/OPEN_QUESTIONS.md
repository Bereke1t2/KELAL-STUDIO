# Open Questions & Deliberate Divergences

**The rule (from the PRD's own "How to read this PRD", echoed in the mobile
`flutter-architecture` skill): never silently resolve an open question.**
Implement *around* it, flag it in code, and stop. This file is the register of
every such item in the backend. Each has a stable slug (referenced from code
comments and `api/openapi.yaml`), what V1 does instead, where it's flagged, and
what input would close it.

Do not "fix" one of these by picking a side in a PR. Closing one is its own
decision, made with the product owner, that updates this file.

---

## PRD open questions (OQ-NN)

### OQ-02 — image aspect ratios
- **Open:** whether image generation offers 2 or 3 aspect ratios.
- **V1 behavior:** accept only `1:1` and `4:5` (the two the PRD's P0 list agrees
  on). `9:16` is **rejected**, not silently added.
- **Flagged in:** `api/openapi.yaml` (`GenerateImageRequest.aspect_ratio` enum +
  description); the Image Generation slice notes in `FEATURE_OWNERSHIP.md`.
- **Closes when:** product confirms the ratio set. Then widen the enum in
  `api/openapi.yaml` and the generation validation together.

### OQ-05 — drafts: device-local vs server-synced
- **Open:** whether drafts sync to the server or stay on-device.
- **V1 behavior:** device-local. There is **no `drafts` table and no
  `/drafts` endpoint**. `draft_local_id` (on reminders and jobs) is an **opaque
  client string** the backend never dereferences.
- **Flagged in:** `models/job.go` (`DraftLocalID` doc), `api/openapi.yaml`
  (`/reminders` `draft_local_id` description), the Reminders slice notes.
- **Closes when:** product decides sync is in scope. Then design a `drafts`
  table + endpoints — a new slice, not a patch to reminders.

### OQ-13 / OQ-19 — prompt confidentiality & data residency
- **Open:** may we log/store provider prompts, and where may data reside?
- **V1 behavior:** provider request/response logging is behind
  `PROVIDER_LOG_REQUESTS`, defaulting **off**. Nothing about prompt content is
  persisted beyond the `GenerationRecord` fields the PRD names.
- **Flagged in:** `config.go` (`ProviderConfig.LogRequests`), `.env.example`
  (`PROVIDER_LOG_REQUESTS`).
- **Closes when:** legal/product answer confidentiality + residency. **Blocking
  for beta** if provider logging is ever turned on.

### OQ-20 — primary AI model
- **Open:** no primary AI provider/model has been chosen.
- **V1 behavior:** the Provider Abstraction Layer ships with **stub providers
  only** (`TEXT_PROVIDER_ORDER=stub`, `IMAGE_PROVIDER_ORDER=stub`) — deterministic
  fakes. Real providers are config-driven and left unimplemented. **No provider
  key ever reaches the mobile client; all keys are server-side env only** (PRD
  §7.8, §10.1).
- **Flagged in:** `config.go` (`ProviderConfig`), `.env.example` (provider
  section + commented key names), `platform/provider/stub/*`,
  `platform/provider/factory/factory.go`.
- **Closes when:** a provider is chosen. Implement it behind the existing
  `TextProvider`/`ImageProvider` interface and add its key to server env — the
  feature code does not change.

### §10.3 — async queue technology (`queue-driver`)
- **Open:** the PRD does not specify a queue/broker for async video jobs.
- **V1 behavior:** a `queue.Queue` interface with an **in-process** default
  (`QUEUE_DRIVER=inproc`). A separate `cmd/worker` process therefore shares **no
  jobs** with the API today; run now, it idles.
- **Flagged in:** `cmd/worker/main.go` (header), `platform/queue/inproc.go`,
  `config.go` (`QueueConfig`), `.env.example`, `api/openapi.yaml`
  (`/generate/video`).
- **Closes when:** a broker (Redis/SQS/…) is chosen. Add a driver behind
  `queue.Queue`; both `api` and `worker` connect to it.

---

## Contract-vs-PRD divergences

The mobile client is already generated against `mobile/api_contract/openapi.yaml`.
Where the PRD data model and that contract disagree, the default is **V1 serves
the contract shape** (so mobile isn't broken) and **flags the mismatch here** — it
does not silently pick a side. `backend/api/openapi.yaml` is the source of truth
and carries the same flags. An item marked **RESOLVED** has since been decided
with the product owner — which may mean choosing the PRD side and requiring mobile
to regenerate; the resolution and its date are recorded in the entry.

### register-verification — RESOLVED 2026-08-25
- **Was:** the contract's `POST /auth/register` returned `AuthTokens`; PRD §11
  specifies a verification-first flow (`{user_id, verification_sent}`).
- **Resolution (product-approved 2026-08-25):** V1 serves the **PRD shape**.
  `POST /auth/register` returns `201 {user_id, verification_sent}` and does **not**
  establish a session; a verification email is sent, the caller verifies via
  `POST /auth/verify-email` (or `.../resend`), then logs in. Content generation is
  gated on a verified email — an unverified caller gets `email_not_verified` (403).
- **Breaking change:** the generated mobile client (built against the old
  `AuthTokens` shape) **must regenerate** against `api/openapi.yaml` and add the
  verify-email step to onboarding — register no longer logs the user in.
- **Implemented in:** `features/auth/service.go` (`Register`, `VerifyEmail`,
  `ResendVerification`), `platform/auth/jwt.go` (verify token + `email_verified`
  access claim), `platform/httpx/middleware/verified.go`, `platform/email/*`,
  `api/openapi.yaml` (`register`, `verifyEmail`, `resendVerification`).

### job-result-field
- **Divergence:** the contract's `Job` exposes `result_asset_id`; the PRD data
  model names the link `result_generation_id` (a `GenerationRecord` id).
- **V1 behavior:** the DB column follows the PRD
  (`jobs.result_generation_record_id`); the video feature maps it to
  `result_asset_id` in its DTO to match the contract. Neither side is renamed.
- **Flagged in:** `models/job.go` (FLAG block), `api/openapi.yaml` (`Job`).
- **Closes when:** video generation is built — reconcile then.

---

## Backend-introduced decisions to ratify

Not PRD open questions, but choices the scaffold made that the team must
confirm rather than inherit blindly.

### error-code-enum
- **Question:** the contract's `ErrorResponse.error_code` is a **closed enum of
  five** codes. The backend also needs codes for 401/403/404/409/429/500/501, so
  it emits nine additional infrastructure codes.
- **V1 behavior:** emit the infra codes (inventing `validation_error` for an auth
  failure would be a lie). `api/openapi.yaml` lists all fourteen.
- **Flagged in:** `apperror/apperror.go` (the two comment blocks).
- **Closes when:** the team decides either to widen the contract enum or to have
  the client treat `error_code` as an open string keyed only on the five.

### schema-authority
- **Question:** two schema paths exist — `AutoMigrate` (from `models.All()`, used
  in dev) and `migrations/*.sql` (golang-migrate, production). Which is
  authoritative?
- **V1 behavior:** both are kept byte-for-byte compatible (matching types + index
  names). Dev uses AutoMigrate; production applies the SQL.
- **Flagged in:** `migrations/000001_init.up.sql` (header), `ARCHITECTURE.md`.
- **Closes when:** the team picks one as canonical (recommended: migrations
  become authoritative once the schema stabilizes, and AutoMigrate is disabled
  outside local dev).

### reset-token-single-use — RESOLVED 2026-08-25
- **Question:** the PRD data model has no password-reset-token table.
- **Resolution:** the reset token stays a **stateless, purpose-bound JWT** (signed
  with the refresh secret, `purpose=pwreset`, 1h TTL — no new table) but is now
  **single-use**: it embeds the account's `token_version`, and confirming a reset
  performs a version-conditional password `UPDATE` that also bumps the version. A
  replayed token — or any token issued before a later password change — no longer
  matches the current version and is rejected.
- **Implemented in:** `models/user.go` (`TokenVersion`), `platform/auth/jwt.go`
  (`ResetClaims.Version`, `GenerateReset`/`ParseReset`), `features/auth/domain.go`
  + `features/auth/repository.go` (`UpdateUserPassword` conditional UPDATE),
  `features/auth/service.go` (`ConfirmPasswordReset`), `api/openapi.yaml`.

### foreign-key constraints
- **Question:** the `models` carry no association tags, so neither AutoMigrate nor
  the SQL migration adds FK constraints; relationships are app-enforced.
- **V1 behavior:** no FK constraints, to keep the two schema paths identical.
- **Flagged in:** `migrations/000001_init.up.sql` (header).
- **Closes when:** the schema stabilizes — add FKs in a new migration as a
  hardening step.

### brandkit-creation
- **Question:** the contract (both `api/openapi.yaml` and the mobile-local
  `mobile/api_contract/openapi.yaml`) exposes only `GET` and `PUT
  /brand-kits/{id}` — there is **no create endpoint**. So how is a brand kit
  first created, and who assigns its id?
- **V1 behavior:** `PUT` is an idempotent, **owner-scoped upsert** — it updates
  the caller's kit, or creates one at the path `id` (client-supplied) owned by
  the caller if none exists. A strictly update-only `PUT` would make a kit
  uncreatable through the documented API. `GET`/`PUT` on a kit owned by someone
  else return **404** (indistinguishable from absent) so ids can't be
  enumerated. `logo_asset_id` is stored as an opaque nullable reference; its
  existence is **not** validated (the asset feature isn't built, and features
  never import each other — referential integrity is deferred to the
  [foreign-key constraints](#foreign-key-constraints) item).
- **Flagged in:** `features/brandkit/service.go` (`Upsert`), `api/openapi.yaml`
  (`/brand-kits/{id}` `put.description`).
- **Closes when:** product confirms the creation flow — e.g. a dedicated
  `POST /brand-kits`, auto-creating a per-user singleton at registration, or
  formally blessing client-supplied ids on `PUT`. Reconcile the contract at that
  point.
