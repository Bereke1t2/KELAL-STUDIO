// Command worker is the async video-generation consumer (PRD §8.4, §10.3).
//
// FLAG (§10.3): the default queue driver is in-process (platform/queue.InProc),
// which lives inside a SINGLE process — so a separate worker binary shares no
// jobs with the API process. Today video jobs would be processed in-api; this
// binary is the consumer SHAPE for when a real broker (Redis/SQS/…) is
// introduced, at which point both api and worker connect to it. Run now, it
// simply idles. See docs/OPEN_QUESTIONS.md.
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/logger"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/queue"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	log := logger.New(cfg.LogLevel)

	if cfg.Queue.Driver != "inproc" {
		return fmt.Errorf("worker: queue driver %q is not implemented (only %q ships today)", cfg.Queue.Driver, "inproc")
	}
	log.Warn("worker started with the in-process queue: it shares NO jobs with the API process (see cmd/worker doc, PRD §10.3)")

	q := queue.NewInProc(64, log)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// TODO(generation/video): replace this placeholder with real processing —
	// decode the payload, run the provider chain, persist the asset, and update
	// the models.Job row (status, attempts, result). Until then it just acks.
	handler := func(_ context.Context, job queue.Job) error {
		log.Info("received job (placeholder handler)", "job_id", job.ID, "type", job.Type)
		return nil
	}

	go q.Start(ctx, handler)
	log.Info("worker running; waiting for signal")
	<-ctx.Done()
	log.Info("worker shutting down")
	return nil
}
