// Package database owns the GORM connection and schema migration. It's the only
// place that dials Postgres; features receive a *gorm.DB and never construct one.
package database

import (
	"fmt"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/config"
)

// Connect opens the pool and applies sizing from config. TranslateError makes
// GORM return sentinel errors (gorm.ErrDuplicatedKey, gorm.ErrRecordNotFound)
// so repositories can map them to apperror.Conflict / apperror.NotFound instead
// of sniffing driver-specific strings.
func Connect(cfg config.DBConfig) (*gorm.DB, error) {
	db, err := gorm.Open(postgres.Open(cfg.DSN()), &gorm.Config{
		Logger:         gormlogger.Default.LogMode(gormlogger.Warn),
		TranslateError: true,
	})
	if err != nil {
		return nil, fmt.Errorf("database: open: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("database: sql handle: %w", err)
	}
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(cfg.ConnMaxLifetime)

	if err := sqlDB.Ping(); err != nil {
		return nil, fmt.Errorf("database: ping: %w", err)
	}
	return db, nil
}
