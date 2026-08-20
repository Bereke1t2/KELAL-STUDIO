package models

import (
	"time"

	"gorm.io/gorm"
)

// Role mirrors the string values in platform/auth (RoleUser/RoleAdmin) so the
// value that lands in a JWT and the value stored in the DB are the same tokens.
type Role string

// RoleUser and RoleAdmin are the account roles carried in the JWT and stored in
// the DB.
const (
	RoleUser  Role = "user"
	RoleAdmin Role = "admin"
)

// User is an account (PRD §10.5). Password is stored only as a bcrypt hash.
// Soft-deleted (DeletedAt) so account deletion (PRD §6.1 DELETE /account) is
// recoverable/auditable rather than a hard wipe.
type User struct {
	Base
	Email           string     `gorm:"uniqueIndex;not null"`
	PasswordHash    string     `gorm:"not null"`
	EmailVerifiedAt *time.Time // nil until verified; see the register-flow FLAG in the auth feature
	Role            Role       `gorm:"type:varchar(16);not null"`
	CreatedAt       time.Time
	UpdatedAt       time.Time
	DeletedAt       gorm.DeletedAt `gorm:"index"`
}
