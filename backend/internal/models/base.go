// Package models holds every GORM entity for the Kelal Studio backend — the
// one relational schema from the PRD data model (§10.5, Fig. 6).
//
// Why one shared package instead of per-feature domain entities: the schema is
// a single connected graph (User is referenced by nearly everything;
// GenerationRecord by generation, quota, and admin). Splitting it per feature
// would duplicate structs and fight GORM's foreign-key/migration model. So this
// package is imported by every feature but imports nothing internal — no import
// cycles, and one AutoMigrate call (database.AutoMigrate) owns the whole schema.
//
// Tradeoff: the GORM tags couple these structs to persistence, which strict
// Clean Architecture would keep out of the domain. That's a deliberate,
// documented call for this timeline (see docs/ARCHITECTURE.md). Handlers still
// map these to/from feature DTOs — models are never serialized to clients raw.
package models

import (
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Base carries the UUID primary key and the ID-generation hook shared by every
// entity. Timestamps are declared per-model (not here) because the PRD schema
// gives some tables created_at only and others created_at + updated_at.
type Base struct {
	ID uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
}

// BeforeCreate assigns a UUID if one wasn't set explicitly. It's a pointer
// method on the embedded Base, so it's promoted onto every model and GORM
// invokes it for all of them — one place to generate ids, DB-agnostic (works
// with Postgres and the in-memory mock repos alike).
func (b *Base) BeforeCreate(*gorm.DB) error {
	if b.ID == uuid.Nil {
		b.ID = uuid.New()
	}
	return nil
}

// All returns a pointer to every model, in dependency order, for AutoMigrate.
// Add new models here when you add them (the compiler won't remind you).
func All() []any {
	return []any{
		&User{},
		&RefreshToken{},
		&Asset{},
		&BrandKit{},
		&ModerationFlag{},
		&GenerationRecord{},
		&Job{},
		&QuotaConsumption{},
		&AdminAuditLog{},
	}
}
