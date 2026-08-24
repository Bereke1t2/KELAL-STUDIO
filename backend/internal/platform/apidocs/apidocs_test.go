package apidocs

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"gopkg.in/yaml.v3"

	apispec "github.com/Bereke1t2/KELAL-STUDIO/backend/api"
)

// These tests serve the REAL embedded contract (apispec.Spec) rather than a
// fixture, so they double as a CI guard: they fail if the go:embed breaks or if
// openapi.yaml is edited into malformed YAML.

func mountedEngine() *gin.Engine {
	gin.SetMode(gin.TestMode)
	e := gin.New()
	Mount(e, apispec.Spec)
	return e
}

func get(e *gin.Engine, path string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, path, nil)
	rec := httptest.NewRecorder()
	e.ServeHTTP(rec, req)
	return rec
}

// TestSpecEndpointServesValidContract asserts /openapi.yaml returns the embedded
// spec as YAML and that it parses with the OpenAPI top-level keys present.
func TestSpecEndpointServesValidContract(t *testing.T) {
	rec := get(mountedEngine(), "/openapi.yaml")
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /openapi.yaml: want 200, got %d", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); !strings.Contains(ct, "yaml") {
		t.Fatalf("GET /openapi.yaml: want a yaml content-type, got %q", ct)
	}

	var doc map[string]any
	if err := yaml.Unmarshal(rec.Body.Bytes(), &doc); err != nil {
		t.Fatalf("embedded spec is not valid YAML: %v", err)
	}
	for _, key := range []string{"openapi", "paths"} {
		if _, ok := doc[key]; !ok {
			t.Fatalf("embedded spec missing top-level %q key", key)
		}
	}
}

// TestDocsUIServed asserts the Swagger UI is reachable and that the bare /docs
// redirects to the trailing-slash base path the UI is mounted at.
func TestDocsUIServed(t *testing.T) {
	e := mountedEngine()

	rec := get(e, "/docs")
	if rec.Code != http.StatusMovedPermanently {
		t.Fatalf("GET /docs: want 301, got %d", rec.Code)
	}
	if loc := rec.Header().Get("Location"); loc != "/docs/" {
		t.Fatalf("GET /docs: want redirect to /docs/, got %q", loc)
	}

	rec = get(e, "/docs/")
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /docs/: want 200, got %d", rec.Code)
	}
	if body := strings.ToLower(rec.Body.String()); !strings.Contains(body, "swagger") {
		t.Fatalf("GET /docs/: expected Swagger UI HTML mentioning \"swagger\", got %d bytes without it", len(body))
	}
}
