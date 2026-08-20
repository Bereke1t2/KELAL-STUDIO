-- 000001_init (down) — drops the initial schema in reverse dependency order.
-- Destructive: this deletes all data. golang-migrate wraps each file in its own
-- transaction; the explicit BEGIN/COMMIT here also makes a manual `psql -f` atomic.

BEGIN;

DROP TABLE IF EXISTS admin_audit_logs;
DROP TABLE IF EXISTS quota_consumptions;
DROP TABLE IF EXISTS jobs;
DROP TABLE IF EXISTS generation_records;
DROP TABLE IF EXISTS moderation_flags;
DROP TABLE IF EXISTS brand_kits;
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS users;

COMMIT;
