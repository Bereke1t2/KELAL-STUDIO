package middleware

import (
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/httpx"
)

// keyedLimiter holds one token-bucket limiter per key (IP or user id).
//
// NOTE (scaffold): the map is never evicted, so a very high cardinality of keys
// would grow memory unbounded. Fine for V1 scale; a production build should add
// LRU/TTL eviction or move to a shared store (Redis) so limits hold across
// replicas. Flagged in docs/OPEN_QUESTIONS.md (§12 abuse control).
type keyedLimiter struct {
	mu       sync.Mutex
	limiters map[string]*rate.Limiter
	r        rate.Limit
	burst    int
}

func newKeyedLimiter(perMinute int) *keyedLimiter {
	if perMinute < 1 {
		perMinute = 1
	}
	return &keyedLimiter{
		limiters: make(map[string]*rate.Limiter),
		r:        rate.Every(time.Minute / time.Duration(perMinute)),
		burst:    perMinute,
	}
}

func (k *keyedLimiter) allow(key string) bool {
	k.mu.Lock()
	l, ok := k.limiters[key]
	if !ok {
		l = rate.NewLimiter(k.r, k.burst)
		k.limiters[key] = l
	}
	k.mu.Unlock()
	return l.Allow()
}

// IPRateLimit throttles by client IP. Applied globally (pre-auth) so
// unauthenticated endpoints (register/login) are protected too (PRD §1.1, §12).
func IPRateLimit(perMinute int) gin.HandlerFunc {
	kl := newKeyedLimiter(perMinute)
	return func(c *gin.Context) {
		if !kl.allow(c.ClientIP()) {
			httpx.Fail(c, apperror.RateLimited("too many requests from this IP; slow down"))
			return
		}
		c.Next()
	}
}

// UserRateLimit throttles by authenticated user id. Applied per-route AFTER
// Auth. If the request isn't authenticated it's a no-op (the IP limiter covers
// it). This is transport-level throttling, distinct from the daily quota
// (PRD §6.14), which the quota feature enforces separately.
func UserRateLimit(perMinute int) gin.HandlerFunc {
	kl := newKeyedLimiter(perMinute)
	return func(c *gin.Context) {
		uid := UserID(c)
		if uid == "" {
			c.Next()
			return
		}
		if !kl.allow(uid) {
			httpx.Fail(c, apperror.RateLimited("too many requests; slow down"))
			return
		}
		c.Next()
	}
}
