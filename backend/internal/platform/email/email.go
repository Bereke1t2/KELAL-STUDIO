// Package email is the shared outbound-email PRIMITIVE: a narrow Sender port
// plus two adapters — a dev logger and a real SMTP client. It deliberately holds
// NO business logic. The auth feature owns *what* to send (the verification and
// password-reset messages, PRD §6.1); this package only delivers a Message.
//
// The design mirrors platform/provider: a small interface with a deterministic
// dev default (LogSender — the analogue of the stub AI providers) and a real
// adapter selected by configuration. No email vendor is baked in; SMTP is the
// neutral transport, and a SaaS provider can be added behind Sender later
// without touching callers.
//
// SECURITY: auth messages carry a live token in their body. LogSender writes
// that body to the logs, which is fine for development but unacceptable in
// production — config.validate() refuses to boot on the log sender when
// APP_ENV=production, the same posture as the dev JWT secrets.
package email

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
)

// Message is a single outbound email. Bodies are plain text: the auth flows send
// short links, not rich HTML, so keeping it text-only avoids an HTML
// templating/escaping surface in V1.
type Message struct {
	To      string
	Subject string
	Body    string
}

// Sender delivers a Message. Implementations must be safe for concurrent use. A
// nil error means the message was handed to the transport, NOT that it reached
// the inbox (SMTP offers no such guarantee).
type Sender interface {
	Send(ctx context.Context, msg Message) error
}

// Provider names the adapter New builds.
const (
	ProviderLog  = "log"  // dev default: logs the message (incl. the link) instead of sending
	ProviderSMTP = "smtp" // real delivery over SMTP
)

// Options is the config-free input to New. cmd/api maps config.EmailConfig onto
// it, so this package never imports config (same decoupling as platform/auth).
type Options struct {
	Provider string // ProviderLog | ProviderSMTP
	From     string // envelope + header From address

	// SMTP settings (used only when Provider == ProviderSMTP).
	SMTPHost     string
	SMTPPort     int
	SMTPUsername string
	SMTPPassword string
}

// New builds the Sender named by opts.Provider. An unknown or misconfigured
// provider is an error, so a bad configuration fails fast at boot rather than
// silently dropping mail at send time.
func New(opts Options, log *slog.Logger) (Sender, error) {
	switch strings.ToLower(strings.TrimSpace(opts.Provider)) {
	case "", ProviderLog:
		return &LogSender{log: log, from: opts.From}, nil
	case ProviderSMTP:
		if opts.SMTPHost == "" {
			return nil, fmt.Errorf("email: provider %q needs EMAIL_SMTP_HOST", ProviderSMTP)
		}
		if opts.From == "" {
			return nil, fmt.Errorf("email: provider %q needs EMAIL_FROM", ProviderSMTP)
		}
		return newSMTPSender(opts), nil
	default:
		return nil, fmt.Errorf("email: unknown provider %q (want %q or %q)", opts.Provider, ProviderLog, ProviderSMTP)
	}
}
