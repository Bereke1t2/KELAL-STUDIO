package models

import (
	"time"

	"github.com/google/uuid"
)

// BrandKit is a user's brand identity applied to generated content (PRD §6.8,
// §10.5). LogoAssetID is nullable — a kit can exist before a logo is uploaded.
type BrandKit struct {
	Base
	UserID            uuid.UUID `gorm:"type:uuid;index;not null"`
	BrandName         string
	LogoAssetID       *uuid.UUID `gorm:"type:uuid"`
	PrimaryColorHex   string
	SecondaryColorHex string
	ToneOfVoice       string
	ContactInfo       string
	CreatedAt         time.Time
	UpdatedAt         time.Time
}
