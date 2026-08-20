// Package quota owns the quota read endpoint (GET /quota/me, PRD §6.14) AND the
// far more important pre-call ENFORCEMENT: before any billable generation, the
// per-user daily cap and the global spend ceiling must be checked and the
// consumption recorded (models.QuotaConsumption). It is a STUB.
//
// TODO(quota): expose an enforcer the generation feature calls BEFORE the
// provider chain — on exceed it returns apperror.QuotaExceeded carrying
// ResetsAt (the contract's only 429-with-reset case). The read endpoint below
// is the small half; enforcement is the load-bearing half (PRD §6.14, §12).
package quota

// Handler is the quota delivery adapter (stub).
type Handler struct{}

// New builds the stub handler. TODO(quota): take a Deps struct (DB, Config for
// the daily limits, Logger).
func New() *Handler { return &Handler{} }
