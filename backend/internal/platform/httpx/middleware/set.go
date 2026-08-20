package middleware

import "github.com/gin-gonic/gin"

// Set is the bundle of route-level middleware handed to each feature's
// RegisterRoutes. Features apply them selectively: public auth routes use none,
// authenticated routes use AuthRequired (+ UserRateLimit), admin routes add
// AdminOnly. Global middleware (request id, logging, recovery, CORS, per-IP
// rate limit) is applied once on the engine in cmd/api and is NOT in this set.
type Set struct {
	AuthRequired  gin.HandlerFunc
	AdminOnly     gin.HandlerFunc
	UserRateLimit gin.HandlerFunc
}
