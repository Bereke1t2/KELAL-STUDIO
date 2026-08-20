package models

import (
	"time"

	"github.com/google/uuid"
)

// GenerationType is the kind of content a generation produced.
type GenerationType string

// GenerationText, GenerationImage, and GenerationVideo are the content kinds a
// generation can produce.
const (
	GenerationText  GenerationType = "text"
	GenerationImage GenerationType = "image"
	GenerationVideo GenerationType = "video"
)

// GenerationRecord is the audit + cache row for one provider generation
// (PRD §10.5). InputHash is the cache key (identical inputs can reuse an output
// instead of re-billing a provider). Provider/Model/ModelVersion capture which
// provider in the abstraction chain actually served it, plus Cost and LatencyMS
// for the usage telemetry the Provider Abstraction Layer emits (PRD §10.1).
type GenerationRecord struct {
	Base
	UserID           uuid.UUID      `gorm:"type:uuid;index;not null"`
	Type             GenerationType `gorm:"type:varchar(16);not null"`
	InputHash        string         `gorm:"index"`
	Provider         string
	Model            string
	ModelVersion     string
	OutputRef        string
	Cost             float64
	LatencyMS        int
	ModerationFlagID *uuid.UUID `gorm:"type:uuid"`
	CreatedAt        time.Time
}
