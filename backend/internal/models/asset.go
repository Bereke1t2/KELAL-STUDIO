package models

import (
	"time"

	"github.com/google/uuid"
)

// Asset is an uploaded or generated image/file (PRD §10.5). StorageRef points
// at the bytes (path/key), which live OUTSIDE any web root. StrippedMetadata
// records that EXIF/etc. was removed on ingest — part of upload hardening
// (PRD §6.8): every uploaded image is re-encoded and its metadata stripped.
type Asset struct {
	Base
	OwnerUserID      uuid.UUID `gorm:"type:uuid;index;not null"`
	StorageRef       string    `gorm:"not null"`
	Width            int
	Height           int
	MimeType         string
	StrippedMetadata bool
	CreatedAt        time.Time
}
