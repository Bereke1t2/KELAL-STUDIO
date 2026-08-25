package email

import (
	"context"
	"log/slog"
)

// LogSender is the dev/default adapter: it logs the message instead of sending
// it, so the verification and password-reset flows are testable end-to-end with
// no mail server. It is the analogue of the stub AI providers.
//
// SECURITY: it logs the full body, which for auth flows contains a LIVE token.
// Acceptable in development, never in production — config.validate() refuses to
// boot with this sender when APP_ENV=production (see config.go), mirroring the
// dev-JWT-secret refusal.
type LogSender struct {
	log  *slog.Logger
	from string
}

// Send logs the message at info level and always succeeds.
func (s *LogSender) Send(_ context.Context, msg Message) error {
	s.log.Info("email NOT sent — dev LogSender (set EMAIL_PROVIDER=smtp to deliver)",
		"from", s.from, "to", msg.To, "subject", msg.Subject, "body", msg.Body)
	return nil
}
