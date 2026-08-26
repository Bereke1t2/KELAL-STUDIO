package email

import (
	"context"
	"fmt"
	"net/smtp"
	"strings"
)

// smtpSender delivers mail over SMTP using the standard library's net/smtp.
// SendMail negotiates STARTTLS when the server advertises it, so SMTPHost:Port
// should be a submission endpoint (typically :587). PLAIN auth is only sent once
// that upgrade succeeds.
type smtpSender struct {
	addr string // host:port
	from string
	auth smtp.Auth
}

func newSMTPSender(opts Options) *smtpSender {
	var auth smtp.Auth
	if opts.SMTPUsername != "" {
		auth = smtp.PlainAuth("", opts.SMTPUsername, opts.SMTPPassword, opts.SMTPHost)
	}
	return &smtpSender{
		addr: fmt.Sprintf("%s:%d", opts.SMTPHost, opts.SMTPPort),
		from: opts.From,
		auth: auth,
	}
}

// Send assembles a minimal text/plain message and hands it to the transport.
// net/smtp has no context hook, so ctx is accepted (for the interface) but not
// wired to a deadline here — a production SaaS adapter would honor it.
func (s *smtpSender) Send(_ context.Context, msg Message) error {
	// Header-injection guard: a newline in a caller-supplied header field would
	// let an attacker inject arbitrary headers/bodies. To is a validated email
	// (binding:"email") and Subject is server-built, but defend regardless.
	if strings.ContainsAny(msg.To, "\r\n") || strings.ContainsAny(msg.Subject, "\r\n") {
		return fmt.Errorf("email: refusing to send message with newline in To/Subject")
	}
	if err := smtp.SendMail(s.addr, s.auth, s.from, []string{msg.To}, buildRFC822(s.from, msg)); err != nil {
		return fmt.Errorf("email: smtp send: %w", err)
	}
	return nil
}

// buildRFC822 assembles a minimal, correctly CRLF-terminated text/plain message.
func buildRFC822(from string, msg Message) []byte {
	var b strings.Builder
	b.WriteString("From: " + from + "\r\n")
	b.WriteString("To: " + msg.To + "\r\n")
	b.WriteString("Subject: " + msg.Subject + "\r\n")
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Content-Type: text/plain; charset=\"utf-8\"\r\n")
	b.WriteString("\r\n")
	b.WriteString(msg.Body)
	return []byte(b.String())
}
