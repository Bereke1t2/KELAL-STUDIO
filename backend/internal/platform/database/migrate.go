package database

import (
	"fmt"

	"gorm.io/gorm"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
)

// AutoMigrate creates/updates every table from the shared models package in one
// call. This is the source of truth for the schema in local dev and V1.
//
// The versioned SQL files under migrations/ exist for the production path
// (reviewable, reversible, ordered) — see docs/OPEN_QUESTIONS.md (PRD §7.8
// mentions backup/restore rehearsal, which needs a real migration history, not
// AutoMigrate). Keep both in sync until the cutover.
func AutoMigrate(db *gorm.DB) error {
	if err := db.AutoMigrate(models.All()...); err != nil {
		return fmt.Errorf("database: automigrate: %w", err)
	}
	return nil
}
