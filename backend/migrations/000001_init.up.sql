-- 000001_init — initial Kelal Studio schema (PRD §10.5, Fig. 6).
--
-- This mirrors internal/models/*, which database.AutoMigrate applies for local
-- dev and non-production. This versioned file is the PRODUCTION schema path
-- (golang-migrate). The two MUST stay in sync until migrations/ becomes the sole
-- authority — see docs/OPEN_QUESTIONS.md (schema-authority). Column types and
-- index names below match GORM's defaults so both paths converge on identical
-- objects (e.g. GORM names a plain `index` `idx_<table>_<column>`).
--
-- UUIDs are generated in the application (models.Base.BeforeCreate), so no
-- server-side default and no uuid extension is required.
--
-- Foreign-key constraints are intentionally OMITTED to match AutoMigrate output
-- (the models carry no association tags today; relationships are app-enforced).
-- Adding FKs is a hardening TODO tracked in docs/OPEN_QUESTIONS.md.

BEGIN;

-- users — accounts (PRD §6.1). Soft-deleted via deleted_at. token_version makes
-- password-reset tokens single-use; failed_login_attempts + locked_until back
-- the lockout policy (both PRD §6.1). bigint + NOT NULL DEFAULT 0 match GORM's
-- mapping of the Go `int` fields so AutoMigrate and this file converge.
CREATE TABLE users (
    id                    uuid        PRIMARY KEY,
    email                 text        NOT NULL,
    password_hash         text        NOT NULL,
    email_verified_at     timestamptz,
    role                  varchar(16) NOT NULL,
    token_version         bigint      NOT NULL DEFAULT 0,
    failed_login_attempts bigint      NOT NULL DEFAULT 0,
    locked_until          timestamptz,
    created_at            timestamptz,
    updated_at            timestamptz,
    deleted_at            timestamptz
);
CREATE UNIQUE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_deleted_at ON users (deleted_at);

-- refresh_tokens — rotation + reuse detection (PRD §6.1). Only a hash is stored.
CREATE TABLE refresh_tokens (
    id              uuid        PRIMARY KEY,
    user_id         uuid        NOT NULL,
    token_hash      text        NOT NULL,
    rotated_from_id uuid,
    expires_at      timestamptz NOT NULL,
    revoked_at      timestamptz,
    created_at      timestamptz
);
CREATE UNIQUE INDEX idx_refresh_tokens_token_hash ON refresh_tokens (token_hash);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_rotated_from_id ON refresh_tokens (rotated_from_id);

-- assets — uploaded/generated files (PRD §6.8). Bytes live outside any web root.
CREATE TABLE assets (
    id                uuid    PRIMARY KEY,
    owner_user_id     uuid    NOT NULL,
    storage_ref       text    NOT NULL,
    width             bigint,
    height            bigint,
    mime_type         text,
    stripped_metadata boolean,
    created_at        timestamptz
);
CREATE INDEX idx_assets_owner_user_id ON assets (owner_user_id);

-- brand_kits — per-user brand identity (PRD §6.8).
CREATE TABLE brand_kits (
    id                  uuid PRIMARY KEY,
    user_id             uuid NOT NULL,
    brand_name          text,
    logo_asset_id       uuid,
    primary_color_hex   text,
    secondary_color_hex text,
    tone_of_voice       text,
    contact_info        text,
    created_at          timestamptz,
    updated_at          timestamptz
);
CREATE INDEX idx_brand_kits_user_id ON brand_kits (user_id);

-- moderation_flags — refusals queued for admin review (PRD §6.4, §6.13).
CREATE TABLE moderation_flags (
    id                   uuid PRIMARY KEY,
    user_id              uuid NOT NULL,
    input_snapshot       text,
    reason               text,
    reviewed_by_admin_id uuid,
    reviewed_at          timestamptz,
    created_at           timestamptz
);
CREATE INDEX idx_moderation_flags_user_id ON moderation_flags (user_id);

-- generation_records — audit + cache row per provider generation (PRD §10.1, §10.5).
CREATE TABLE generation_records (
    id                 uuid        PRIMARY KEY,
    user_id            uuid        NOT NULL,
    type               varchar(16) NOT NULL,
    input_hash         text,
    provider           text,
    model              text,
    model_version      text,
    output_ref         text,
    cost               decimal,
    latency_ms         bigint,
    moderation_flag_id uuid,
    created_at         timestamptz
);
CREATE INDEX idx_generation_records_user_id ON generation_records (user_id);
CREATE INDEX idx_generation_records_input_hash ON generation_records (input_hash);

-- jobs — async generation lifecycle, e.g. video (PRD §8.4, §10.3, §10.5).
-- result_generation_record_id follows the PRD naming; the video feature maps it
-- to result_asset_id in its DTO for the mobile contract (see the model's FLAG).
CREATE TABLE jobs (
    id                          uuid        PRIMARY KEY,
    user_id                     uuid        NOT NULL,
    draft_local_id              text,
    status                      varchar(16) NOT NULL,
    attempts                    bigint,
    max_attempts                bigint,
    result_generation_record_id uuid,
    expires_at                  timestamptz,
    created_at                  timestamptz,
    updated_at                  timestamptz
);
CREATE INDEX idx_jobs_user_id ON jobs (user_id);
CREATE INDEX idx_jobs_status ON jobs (status);

-- quota_consumptions — one row per user per day; enforced BEFORE provider calls
-- (PRD §6.14, §12). (user_id, period) is unique for a single upsert-and-check.
CREATE TABLE quota_consumptions (
    id               uuid        PRIMARY KEY,
    user_id          uuid        NOT NULL,
    period           varchar(10) NOT NULL,
    text_calls_used  bigint,
    image_calls_used bigint,
    cap_reached_at   timestamptz,
    created_at       timestamptz,
    updated_at       timestamptz
);
CREATE UNIQUE INDEX idx_quota_user_period ON quota_consumptions (user_id, period);

-- admin_audit_logs — append-only trail of privileged actions (PRD §6.13).
CREATE TABLE admin_audit_logs (
    id            uuid PRIMARY KEY,
    admin_user_id uuid NOT NULL,
    action        text NOT NULL,
    target_ref    text,
    created_at    timestamptz
);
CREATE INDEX idx_admin_audit_logs_admin_user_id ON admin_audit_logs (admin_user_id);

COMMIT;
