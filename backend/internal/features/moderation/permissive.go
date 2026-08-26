package moderation

import "context"

// permissiveChecker allows all content through. It is used when
// USE_MOCK_DATA=true so the full generation flow can be tested end-to-end
// without a real moderation backend.
type permissiveChecker struct{}

// NewPermissiveChecker returns a checker that always allows content.
// Use only in dev/mock mode — never in production.
func NewPermissiveChecker() Checker { return permissiveChecker{} }

func (permissiveChecker) CheckText(_ context.Context, _, _ string) (Decision, error) {
	return Decision{Allowed: true}, nil
}
