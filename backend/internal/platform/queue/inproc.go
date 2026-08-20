package queue

import (
	"context"
	"fmt"
	"log/slog"
)

// InProc is a channel-backed in-process queue — the default (PRD §10.3 leaves
// the broker unspecified). It is NOT durable: jobs live only in memory, so a
// restart drops queued work. Fine for local dev and a single-instance V1; a
// real broker is required before horizontal scaling. Flagged in
// docs/OPEN_QUESTIONS.md.
type InProc struct {
	ch  chan Job
	log *slog.Logger
}

// NewInProc builds an in-process queue with the given buffer size.
func NewInProc(buffer int, log *slog.Logger) *InProc {
	if buffer < 1 {
		buffer = 1
	}
	return &InProc{ch: make(chan Job, buffer), log: log}
}

// Enqueue submits a job, blocking only until buffer space is free or ctx ends.
func (q *InProc) Enqueue(ctx context.Context, job Job) error {
	select {
	case q.ch <- job:
		return nil
	case <-ctx.Done():
		return fmt.Errorf("queue: enqueue cancelled: %w", ctx.Err())
	}
}

// Start consumes until ctx is cancelled. A handler error is logged here; retry
// accounting belongs to the worker that owns the models.Job row.
func (q *InProc) Start(ctx context.Context, handler Handler) {
	for {
		select {
		case job := <-q.ch:
			if err := handler(ctx, job); err != nil && q.log != nil {
				q.log.Error("queue: job handler failed", "job_id", job.ID, "type", job.Type, "error", err.Error())
			}
		case <-ctx.Done():
			return
		}
	}
}
