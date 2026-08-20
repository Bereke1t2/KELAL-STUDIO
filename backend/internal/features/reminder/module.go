// Package reminder owns scheduling a "post this later" reminder for a draft
// (POST /reminders, PRD §6.12). It is a STUB.
//
// Flags this feature must carry:
//   - Times are ALWAYS UTC on the wire (scheduled_at_utc); local-time
//     conversion happens only at the mobile presentation layer. Store UTC,
//     never a local time or a floating wall-clock (PRD §6.12).
//   - OQ-05: drafts are device-local in V1 — there is NO drafts table and NO
//     /drafts endpoint. draft_local_id is an OPAQUE client string the backend
//     stores and echoes back; it must NOT be treated as a server FK.
//
// TODO(reminder): implement by copying the auth feature's layout.
package reminder

// Handler is the reminder delivery adapter (stub).
type Handler struct{}

// New builds the stub handler. TODO(reminder): take a Deps struct (DB, Config,
// Logger) and add a models.Reminder + notification-dispatch mechanism.
func New() *Handler { return &Handler{} }
