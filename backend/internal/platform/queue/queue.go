// Package queue is the async job abstraction behind video generation (PRD §8.4,
// §10.3). The PRD leaves the queue TECHNOLOGY unspecified, so features depend on
// the Queue interface, never a concrete broker — swapping the in-process
// default for Redis/SQS/etc. later is a one-file change in wiring.
package queue

import "context"

// Job is a unit of async work. Payload is opaque JSON the handler decodes; the
// queue never inspects it. ID correlates with a models.Job row.
type Job struct {
	ID      string
	Type    string // e.g. "video"
	Payload []byte
}

// Handler processes one job. Returning an error signals failure; retry/backoff
// policy (models.Job.Attempts/MaxAttempts) is the worker's concern, not the
// queue's.
type Handler func(ctx context.Context, job Job) error

// Queue is the minimal producer/consumer contract.
type Queue interface {
	// Enqueue submits a job. It must not block indefinitely; it respects ctx.
	Enqueue(ctx context.Context, job Job) error
	// Start consumes jobs and dispatches them to handler until ctx is cancelled.
	// It blocks, so callers run it in its own goroutine.
	Start(ctx context.Context, handler Handler)
}
