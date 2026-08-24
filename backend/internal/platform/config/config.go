// Package config loads all runtime configuration from the environment into one
// typed, validated struct. Nothing else in the codebase reads os.Getenv — this
// is the single door for configuration, so the surface is auditable (which
// matters for the provider keys and JWT secrets that live here, PRD §7.8).
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// Config is the fully-resolved runtime configuration.
type Config struct {
	Env      string // "development" | "production"
	HTTPPort string
	LogLevel string

	// UseMockData runs the whole backend on in-memory repositories — the
	// analogue of the mobile app's Env.useMockApi. When true, DB is never dialed.
	UseMockData bool

	DB       DBConfig
	JWT      JWTConfig
	RateLim  RateLimitConfig
	Quota    QuotaConfig
	Moderation ModerationConfig
	Provider   ProviderConfig
	Queue      QueueConfig
	Asset      AssetConfig
}

// DBConfig holds the PostgreSQL connection settings and pool tuning.
type DBConfig struct {
	URL             string // full DSN; wins over the assembled parts if set
	Host            string
	Port            string
	User            string
	Password        string
	Name            string
	SSLMode         string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

// DSN returns the connection string, preferring an explicit URL.
func (d DBConfig) DSN() string {
	if d.URL != "" {
		return d.URL
	}
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		d.Host, d.Port, d.User, d.Password, d.Name, d.SSLMode,
	)
}

// JWTConfig holds the access/refresh signing secrets and token lifetimes.
type JWTConfig struct {
	AccessSecret  string
	RefreshSecret string
	AccessTTL     time.Duration
	RefreshTTL    time.Duration
}

// RateLimitConfig holds the per-user and per-IP request-rate limits.
type RateLimitConfig struct {
	PerUserPerMinute int
	PerIPPerMinute   int
}

// QuotaConfig holds the daily generation caps and the global spend ceiling.
type QuotaConfig struct {
	TextDaily             int
	ImageDaily            int
	GlobalDailyCeilingUSD float64
}

// ModerationConfig configures the content moderation service (PRD §6.4).
type ModerationConfig struct {
	Provider string // "stub" (fail-closed, refuses everything) or "openai"
	APIKey   string // required when Provider == "openai"; reads OPENAI_API_KEY
}

// ProviderConfig configures the Provider Abstraction Layer: the failover order
// per modality, the per-provider timeout, and request logging (off by default).
type ProviderConfig struct {
	TextOrder   []string // failover order, e.g. ["nemotron","gemini"]; ["stub"] by default
	ImageOrder  []string
	Timeout     time.Duration
	LogRequests bool // OQ-13/OQ-19: OFF until confidentiality/residency are resolved
}

// QueueConfig configures the async job queue (PRD §10.3).
type QueueConfig struct {
	Driver           string // "inproc"
	VideoMaxAttempts int
}

// AssetConfig holds the upload-hardening limits and the storage location.
type AssetConfig struct {
	StorageDir   string
	MaxBytes     int64
	MaxDimension int
	MinDimension int
}

// These are deliberately obvious DEV-ONLY placeholders. validate() refuses to
// boot with either when APP_ENV=production, so they can never stand in for a
// real credential. The //nolint:gosec silences G101's name-based heuristic,
// which flags any identifier containing "secret" that is assigned a literal.
const (
	devAccessSecretPlaceholder  = "dev-access-secret-change-me"  //nolint:gosec // G101: dev-only placeholder, refused in production by validate()
	devRefreshSecretPlaceholder = "dev-refresh-secret-change-me" //nolint:gosec // G101: dev-only placeholder, refused in production by validate()
)

// Load reads .env (if present) then the environment, and validates the result.
// A missing .env is not an error — real deployments inject env directly.
func Load() (*Config, error) {
	_ = godotenv.Load() // best-effort; ignore "file not found"

	cfg := &Config{
		Env:         getStr("APP_ENV", "development"),
		HTTPPort:    getStr("HTTP_PORT", "8080"),
		LogLevel:    getStr("LOG_LEVEL", "info"),
		UseMockData: getBool("USE_MOCK_DATA", false),
		DB: DBConfig{
			URL:             getStr("DATABASE_URL", ""),
			Host:            getStr("DB_HOST", "localhost"),
			Port:            getStr("DB_PORT", "5432"),
			User:            getStr("DB_USER", "kelal"),
			Password:        getStr("DB_PASSWORD", "kelal"),
			Name:            getStr("DB_NAME", "kelal_studio"),
			SSLMode:         getStr("DB_SSLMODE", "disable"),
			MaxOpenConns:    getInt("DB_MAX_OPEN_CONNS", 20),
			MaxIdleConns:    getInt("DB_MAX_IDLE_CONNS", 5),
			ConnMaxLifetime: getDuration("DB_CONN_MAX_LIFETIME", time.Hour),
		},
		JWT: JWTConfig{
			AccessSecret:  getStr("JWT_ACCESS_SECRET", devAccessSecretPlaceholder),
			RefreshSecret: getStr("JWT_REFRESH_SECRET", devRefreshSecretPlaceholder),
			AccessTTL:     getDuration("JWT_ACCESS_TTL", 15*time.Minute),
			RefreshTTL:    getDuration("JWT_REFRESH_TTL", 720*time.Hour),
		},
		RateLim: RateLimitConfig{
			PerUserPerMinute: getInt("RATE_LIMIT_PER_MINUTE", 60),
			PerIPPerMinute:   getInt("RATE_LIMIT_IP_PER_MINUTE", 120),
		},
		Quota: QuotaConfig{
			TextDaily:             getInt("QUOTA_TEXT_DAILY", 50),
			ImageDaily:            getInt("QUOTA_IMAGE_DAILY", 20),
			GlobalDailyCeilingUSD: getFloat("GLOBAL_DAILY_SPEND_CEILING_USD", 0),
		},
		Moderation: ModerationConfig{
			Provider: getStr("MODERATION_PROVIDER", "stub"),
			APIKey:   getStr("OPENAI_API_KEY", ""),
		},
		Provider: ProviderConfig{
			TextOrder:   getCSV("TEXT_PROVIDER_ORDER", []string{"stub"}),
			ImageOrder:  getCSV("IMAGE_PROVIDER_ORDER", []string{"stub"}),
			Timeout:     getDuration("PROVIDER_TIMEOUT", 20*time.Second),
			LogRequests: getBool("PROVIDER_LOG_REQUESTS", false),
		},
		Queue: QueueConfig{
			Driver:           getStr("QUEUE_DRIVER", "inproc"),
			VideoMaxAttempts: getInt("VIDEO_JOB_MAX_ATTEMPTS", 3),
		},
		Asset: AssetConfig{
			StorageDir:   getStr("ASSET_STORAGE_DIR", "./storage/assets"),
			MaxBytes:     int64(getInt("ASSET_MAX_BYTES", 10*1024*1024)),
			MaxDimension: getInt("ASSET_MAX_DIMENSION", 4096),
			MinDimension: getInt("ASSET_MIN_DIMENSION", 200),
		},
	}

	if err := cfg.validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}

// IsProduction reports whether the app is running with APP_ENV=production.
func (c *Config) IsProduction() bool { return c.Env == "production" }

func (c *Config) validate() error {
	// In production, refuse to run with the shipped dev secrets — that would be
	// a trivially-forgeable JWT (PRD §7.8).
	if c.IsProduction() {
		if c.JWT.AccessSecret == devAccessSecretPlaceholder || c.JWT.RefreshSecret == devRefreshSecretPlaceholder {
			return fmt.Errorf("config: JWT secrets must be set to non-default values when APP_ENV=production")
		}
		if c.UseMockData {
			return fmt.Errorf("config: USE_MOCK_DATA must be false in production")
		}
	}
	if c.JWT.AccessSecret == "" || c.JWT.RefreshSecret == "" {
		return fmt.Errorf("config: JWT_ACCESS_SECRET and JWT_REFRESH_SECRET are required")
	}
	return nil
}

// ── env readers ──────────────────────────────────────────────────────────────

func getStr(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

func getInt(key string, def int) int {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func getFloat(key string, def float64) float64 {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return def
}

func getBool(key string, def bool) bool {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return def
}

func getDuration(key string, def time.Duration) time.Duration {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}

func getCSV(key string, def []string) []string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		parts := strings.Split(v, ",")
		out := make([]string, 0, len(parts))
		for _, p := range parts {
			if s := strings.TrimSpace(p); s != "" {
				out = append(out, s)
			}
		}
		if len(out) > 0 {
			return out
		}
	}
	return def
}
