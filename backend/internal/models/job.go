package models

import (
	"time"

	"github.com/google/uuid"
)

// JobStatus is the lifecycle of an async job (video generation, PRD §10.3).
type JobStatus string

// JobQueued, JobRunning, JobDone, and JobFailed are the lifecycle states of an
// async job.
const (
	JobQueued  JobStatus = "queued"
	JobRunning JobStatus = "running"
	JobDone    JobStatus = "done"
	JobFailed  JobStatus = "failed"
)

// Job tracks an async generation (PRD §10.5). DraftLocalID is an OPAQUE
// client-supplied string, not a server row — drafts are device-local in V1
// (OQ-05), so the backend never dereferences it.
//
// FLAG (contract vs PRD): the mobile contract's Job exposes result_asset_id,
// while the PRD data model names the link result_generation_id. This column
// follows the PRD (a GenerationRecord id); the video-generation feature maps it
// to result_asset_id in its DTO to match the contract the mobile client is
// generated against. Reconcile when video generation is built — do not silently
// rename either side. Tracked in docs/OPEN_QUESTIONS.md.
type Job struct {
	Base
	UserID                   uuid.UUID `gorm:"type:uuid;index;not null"`
	DraftLocalID             string    // opaque; see note above
	Status                   JobStatus `gorm:"type:varchar(16);not null;index"`
	Attempts                 int
	MaxAttempts              int
	ResultGenerationRecordID *uuid.UUID `gorm:"type:uuid"`
	ExpiresAt                time.Time
	CreatedAt                time.Time
	UpdatedAt                time.Time
}
