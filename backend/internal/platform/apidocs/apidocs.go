// Package apidocs serves the API's OpenAPI contract and an interactive Swagger
// UI. It renders the committed spec (api.Spec, embedded from api/openapi.yaml)
// as-is — the spec is the source of truth, never regenerated from code.
//
// This lives in platform rather than httpx on purpose: httpx is documented to
// import only apperror + gin (see docs/ARCHITECTURE.md), so the Swagger UI
// dependency is quarantined here. Mount is called from cmd/api only in
// non-production; the docs are an integration aid, not a production surface.
package apidocs

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/swaggest/swgui/v5emb"
)

// Routes are mounted at the engine root (outside /v1), alongside /healthz —
// they document the API surface but are not part of it.
const (
	specPath = "/openapi.yaml"
	docsPath = "/docs"
)

// Mount registers the spec endpoint and the Swagger UI on the given engine:
//
//	GET /openapi.yaml  the raw embedded contract
//	GET /docs          Swagger UI (redirects to /docs/), pointed at /openapi.yaml
//
// Swagger UI's "Try it out" prepends the spec's server URL (/v1), so requests
// hit /v1/... on the same origin — already covered by the global CORS
// middleware. Call this only when !cfg.IsProduction().
func Mount(e *gin.Engine, spec []byte) {
	e.GET(specPath, func(c *gin.Context) {
		c.Data(http.StatusOK, "application/yaml", spec)
	})

	// v5emb.New embeds the Swagger UI v5 assets in the returned handler, so the
	// page renders fully offline. It serves the index at basePath and its
	// assets beneath it, expecting the full path (no prefix stripping) — hence
	// the "/docs/*any" wildcard, plus a redirect from the bare "/docs".
	ui := v5emb.New("Kelal Studio API", specPath, docsPath+"/")
	e.GET(docsPath, func(c *gin.Context) {
		c.Redirect(http.StatusMovedPermanently, docsPath+"/")
	})
	e.GET(docsPath+"/*any", gin.WrapH(ui))
}
