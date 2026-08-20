package provider

import (
	"context"
	"errors"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// Provider sentinel errors. Implementations return these (optionally wrapped)
// so the chain can classify a failure without knowing the concrete provider.
var (
	// ErrUnavailable: the provider couldn't be reached / returned 5xx / refused.
	// The chain fails over to the next provider.
	ErrUnavailable = errors.New("provider: unavailable")

	// ErrMalformedOutput: the provider responded but the output couldn't be
	// parsed into the normalized result (PRD §10.1 defensive parsing).
	ErrMalformedOutput = errors.New("provider: malformed output")
)

// classify maps a provider/chain failure to the contract error taxonomy.
//   - context deadline / ErrUnavailable  → provider_timeout (504)
//   - ErrMalformedOutput                 → malformed_output (502)
//   - anything else                      → provider_timeout (the safe default:
//     from the client's view the generation didn't happen)
//
// Moderation refusals are NOT produced here — moderation is a separate,
// pre-generation service (PRD §6.4); by the time we call a provider the input
// has already passed moderation.
func classify(err error, msg string) *apperror.Error {
	switch {
	case errors.Is(err, ErrMalformedOutput):
		return apperror.MalformedOutput(msg).WithCause(err)
	case errors.Is(err, context.DeadlineExceeded), errors.Is(err, context.Canceled), errors.Is(err, ErrUnavailable):
		return apperror.ProviderTimeout(msg).WithCause(err)
	default:
		return apperror.ProviderTimeout(msg).WithCause(err)
	}
}
