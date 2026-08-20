package httpx

import "github.com/gin-gonic/gin"

// NewRouter builds the gin engine with the given global middleware already
// applied, and returns both the engine and the /v1 route group that features
// mount onto. Middleware handlers are passed IN (constructed by the caller from
// the middleware package) so this package never imports middleware — that keeps
// the dependency arrows pointing one way and avoids an import cycle.
//
// Route registration itself lives in each feature (feature.RegisterRoutes(v1,
// ...)), called from cmd/api/main.go — the router doesn't know the features.
func NewRouter(releaseMode bool, global ...gin.HandlerFunc) (*gin.Engine, *gin.RouterGroup) {
	if releaseMode {
		gin.SetMode(gin.ReleaseMode)
	}
	// gin.New (not gin.Default) — we supply our own recovery + logging
	// middleware so their output matches the app's structured logger.
	e := gin.New()
	e.Use(global...)

	// Liveness probe, outside /v1 (infra concern, not part of the API surface).
	e.GET("/healthz", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })

	v1 := e.Group("/v1")
	return e, v1
}
