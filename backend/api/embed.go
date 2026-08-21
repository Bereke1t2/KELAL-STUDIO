// Package api embeds the canonical OpenAPI contract (openapi.yaml) so the
// running binary serves exactly the committed spec, with no runtime filesystem
// dependency. The spec — not this file — is the SOURCE OF TRUTH for the HTTP
// surface; see openapi.yaml's own header and docs/ARCHITECTURE.md. The docs UI
// (internal/platform/apidocs) renders these bytes; it is never regenerated from
// handler annotations, which would create a competing source of truth.
package api

import _ "embed"

// Spec is the raw bytes of api/openapi.yaml.
//
//go:embed openapi.yaml
var Spec []byte
