// Package admin owns the admin portal API (PRD §6.13): aggregate usage, the
// moderation flag queue, flag review, and per-user limit overrides. It is a
// STUB. These endpoints are backend-spec (the admin surface is a future web
// portal), not part of the mobile contract.
//
// Non-negotiable when built (PRD §6.13):
//   - Every route is gated by BOTH authentication and the admin role
//     (mw.AuthRequired + mw.AdminOnly).
//   - Every state-changing admin action writes a models.AdminAuditLog row
//     (who, what, when, target) — admin actions are never silent.
//
// TODO(admin): implement by copying the auth feature's layout.
package admin

// Handler is the admin delivery adapter (stub).
type Handler struct{}

// New builds the stub handler. TODO(admin): take a Deps struct (DB, Logger) and
// an audit-log writer every mutation must call.
func New() *Handler { return &Handler{} }
