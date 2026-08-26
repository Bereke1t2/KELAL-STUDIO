package auth

import (
	"context"
	"io"
	"log/slog"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
	mail "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/email"
)

// These tests run entirely on the in-memory repository and a real JWT manager —
// no Postgres, no network. They are the pattern each feature's service_test.go
// copies: construct the service with the mock adapter, exercise use cases, and
// assert on the returned (result, *apperror.Error).

func testManager() *auth.Manager {
	return auth.NewManager("test-access-secret", "test-refresh-secret", 15*time.Minute, time.Hour)
}

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

// capturingMailer is a fake email.Sender that records every message, so a test
// can both assert what was "sent" and pull the token out of the link — exercising
// the real verification/reset flow end to end instead of minting tokens by hand.
type capturingMailer struct {
	sent []mail.Message
}

func (m *capturingMailer) Send(_ context.Context, msg mail.Message) error {
	m.sent = append(m.sent, msg)
	return nil
}

// newTestServiceWith builds a service on the mock repo with an explicit policy.
func newTestServiceWith(cfg ServiceConfig) (*Service, *auth.Manager, *capturingMailer) {
	mgr := testManager()
	mailer := &capturingMailer{}
	svc := NewService(NewMockRepository(), mgr, discardLogger(), mailer, cfg)
	return svc, mgr, mailer
}

// newTestService builds a service with the default policy (see withDefaults).
func newTestService() (*Service, *auth.Manager, *capturingMailer) {
	return newTestServiceWith(ServiceConfig{})
}

// mailToken extracts and URL-decodes the `token=` value from an email body's
// link — the token a real recipient would click through with.
func mailToken(t *testing.T, body string) string {
	t.Helper()
	i := strings.Index(body, "token=")
	if i < 0 {
		t.Fatalf("no token in email body:\n%s", body)
	}
	raw := body[i+len("token="):]
	if j := strings.IndexAny(raw, "\r\n"); j >= 0 {
		raw = raw[:j]
	}
	tok, err := url.QueryUnescape(raw)
	if err != nil {
		t.Fatalf("unescape token %q: %v", raw, err)
	}
	return tok
}

func TestRegister(t *testing.T) {
	ctx := context.Background()
	svc, _, mailer := newTestService()

	// Mixed-case + surrounding whitespace must normalize. Registration returns
	// {user_id, verification_sent} and does NOT establish a session (PRD §11).
	res, aerr := svc.Register(ctx, " User@Example.com ", "password123")
	if aerr != nil {
		t.Fatalf("Register: unexpected error: %v", aerr)
	}
	if res.UserID == "" {
		t.Fatalf("Register: expected a user id, got %+v", res)
	}
	if !res.VerificationSent {
		t.Fatalf("Register: expected verification_sent=true, got %+v", res)
	}
	// Exactly one verification email, addressed to the normalized email.
	if len(mailer.sent) != 1 {
		t.Fatalf("Register: want 1 verification email, got %d", len(mailer.sent))
	}
	if got := mailer.sent[0].To; got != "user@example.com" {
		t.Fatalf("Register: verification email To=%q, want normalized address", got)
	}

	// Re-registering the same (normalized) email is a conflict.
	_, aerr = svc.Register(ctx, "user@example.com", "password123")
	if aerr == nil || aerr.Code != apperror.CodeConflict {
		t.Fatalf("Register duplicate: want conflict, got %v", aerr)
	}
}

func TestLogin(t *testing.T) {
	ctx := context.Background()
	svc, _, _ := newTestService()
	if _, aerr := svc.Register(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}

	// Correct credentials succeed (case-insensitive email).
	if _, aerr := svc.Login(ctx, "USER@example.com", "password123"); aerr != nil {
		t.Fatalf("Login valid: unexpected error: %v", aerr)
	}

	// Wrong password and unknown email must both return the SAME generic 401.
	_, wrongPass := svc.Login(ctx, "user@example.com", "nope")
	_, unknown := svc.Login(ctx, "ghost@example.com", "password123")
	if wrongPass == nil || unknown == nil {
		t.Fatalf("Login failures: expected errors, got wrongPass=%v unknown=%v", wrongPass, unknown)
	}
	if wrongPass.Code != apperror.CodeUnauthorized || unknown.Code != apperror.CodeUnauthorized {
		t.Fatalf("Login failures: want unauthorized, got %v / %v", wrongPass.Code, unknown.Code)
	}
	if wrongPass.Message != unknown.Message {
		t.Fatalf("Login failures must be indistinguishable: %q vs %q", wrongPass.Message, unknown.Message)
	}
}

func TestRefreshRotationAndReuseDetection(t *testing.T) {
	ctx := context.Background()
	svc, _, _ := newTestService()
	if _, aerr := svc.Register(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}
	// Registration no longer issues tokens — log in to get the first pair.
	first, aerr := svc.Login(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("setup Login: %v", aerr)
	}

	// A valid refresh rotates to a new pair.
	second, aerr := svc.Refresh(ctx, first.Refresh)
	if aerr != nil {
		t.Fatalf("Refresh: unexpected error: %v", aerr)
	}
	if second.Refresh == first.Refresh {
		t.Fatalf("Refresh: expected a rotated refresh token, got the same one")
	}

	// Reusing the now-rotated first token is treated as compromise: rejected...
	if _, reuse := svc.Refresh(ctx, first.Refresh); reuse == nil || reuse.Code != apperror.CodeUnauthorized {
		t.Fatalf("Refresh reuse: want unauthorized, got %v", reuse)
	}
	// ...and the whole chain is revoked, so even the good second token is dead.
	if _, after := svc.Refresh(ctx, second.Refresh); after == nil || after.Code != apperror.CodeUnauthorized {
		t.Fatalf("Refresh after reuse: want the chain revoked (unauthorized), got %v", after)
	}
}

func TestPasswordResetConfirm(t *testing.T) {
	ctx := context.Background()
	svc, _, mailer := newTestService()
	if _, aerr := svc.Register(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}

	// Requesting a reset always reports success, even for an unknown email, and
	// sends nothing in that case.
	if aerr := svc.RequestPasswordReset(ctx, "ghost@example.com"); aerr != nil {
		t.Fatalf("RequestPasswordReset unknown: want nil, got %v", aerr)
	}

	// For the real account the reset token is delivered by email.
	if aerr := svc.RequestPasswordReset(ctx, "user@example.com"); aerr != nil {
		t.Fatalf("RequestPasswordReset: want nil, got %v", aerr)
	}
	resetToken := mailToken(t, mailer.sent[len(mailer.sent)-1].Body)

	// A valid reset token lets the user set a new password.
	if aerr := svc.ConfirmPasswordReset(ctx, resetToken, "newpassword456"); aerr != nil {
		t.Fatalf("ConfirmPasswordReset: unexpected error: %v", aerr)
	}

	// Single-use: replaying the same token fails — the version it carried was
	// bumped by the first confirm (the reset-token-single-use guarantee).
	if aerr := svc.ConfirmPasswordReset(ctx, resetToken, "another789"); aerr == nil || aerr.Code != apperror.CodeUnauthorized {
		t.Fatalf("ConfirmPasswordReset replay: want unauthorized, got %v", aerr)
	}

	// Old password no longer works; the first new one does (the replay didn't take).
	if _, old := svc.Login(ctx, "user@example.com", "password123"); old == nil {
		t.Fatalf("Login old password: expected failure after reset")
	}
	if _, aerr := svc.Login(ctx, "user@example.com", "newpassword456"); aerr != nil {
		t.Fatalf("Login new password: unexpected error: %v", aerr)
	}

	// A garbage reset token is rejected.
	if aerr := svc.ConfirmPasswordReset(ctx, "not-a-token", "whatever789"); aerr == nil || aerr.Code != apperror.CodeUnauthorized {
		t.Fatalf("ConfirmPasswordReset bad token: want unauthorized, got %v", aerr)
	}
}

func TestVerifyEmail(t *testing.T) {
	ctx := context.Background()
	svc, mgr, mailer := newTestService()
	res, aerr := svc.Register(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}

	// The access token issued before verification carries email_verified=false.
	before, aerr := svc.Login(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("Login (pre-verify): %v", aerr)
	}
	if claims, err := mgr.ParseAccess(before.Access); err != nil {
		t.Fatalf("parse access: %v", err)
	} else if claims.EmailVerified {
		t.Fatalf("pre-verify access token should have email_verified=false")
	}

	// Consume the token from the registration email.
	if aerr := svc.VerifyEmail(ctx, mailToken(t, mailer.sent[0].Body)); aerr != nil {
		t.Fatalf("VerifyEmail: unexpected error: %v", aerr)
	}
	// Idempotent: verifying again still succeeds.
	if aerr := svc.VerifyEmail(ctx, mailToken(t, mailer.sent[0].Body)); aerr != nil {
		t.Fatalf("VerifyEmail (idempotent): unexpected error: %v", aerr)
	}

	// A fresh login now mints a verified access token — this is what the
	// generation gate reads.
	after, aerr := svc.Login(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("Login (post-verify): %v", aerr)
	}
	if claims, err := mgr.ParseAccess(after.Access); err != nil {
		t.Fatalf("parse access: %v", err)
	} else if !claims.EmailVerified {
		t.Fatalf("post-verify access token should have email_verified=true")
	}

	// A garbage token is rejected...
	if aerr := svc.VerifyEmail(ctx, "not-a-token"); aerr == nil || aerr.Code != apperror.CodeUnauthorized {
		t.Fatalf("VerifyEmail bad token: want unauthorized, got %v", aerr)
	}
	// ...and a reset token (wrong purpose) must not double as a verify token.
	reset, err := mgr.GenerateReset(res.UserID, 0, time.Hour)
	if err != nil {
		t.Fatalf("GenerateReset: %v", err)
	}
	if aerr := svc.VerifyEmail(ctx, reset); aerr == nil || aerr.Code != apperror.CodeUnauthorized {
		t.Fatalf("VerifyEmail with reset token: want unauthorized, got %v", aerr)
	}
}

func TestResendVerification(t *testing.T) {
	ctx := context.Background()
	svc, _, mailer := newTestService()

	// Unknown email: always nil (anti-enumeration), and nothing is sent.
	if aerr := svc.ResendVerification(ctx, "ghost@example.com"); aerr != nil {
		t.Fatalf("ResendVerification unknown: want nil, got %v", aerr)
	}
	if len(mailer.sent) != 0 {
		t.Fatalf("ResendVerification unknown: expected no email, got %d", len(mailer.sent))
	}

	// Register (1 email), then resend (2nd email) for an unverified account.
	if _, aerr := svc.Register(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}
	if aerr := svc.ResendVerification(ctx, "user@example.com"); aerr != nil {
		t.Fatalf("ResendVerification: want nil, got %v", aerr)
	}
	if len(mailer.sent) != 2 {
		t.Fatalf("after register+resend: want 2 emails, got %d", len(mailer.sent))
	}

	// After verifying, a resend still reports success but sends nothing more.
	if aerr := svc.VerifyEmail(ctx, mailToken(t, mailer.sent[0].Body)); aerr != nil {
		t.Fatalf("VerifyEmail: %v", aerr)
	}
	if aerr := svc.ResendVerification(ctx, "user@example.com"); aerr != nil {
		t.Fatalf("ResendVerification (verified): want nil, got %v", aerr)
	}
	if len(mailer.sent) != 2 {
		t.Fatalf("verified account should not receive another email, got %d", len(mailer.sent))
	}
}

func TestLoginLockout(t *testing.T) {
	ctx := context.Background()
	svc, _, _ := newTestServiceWith(ServiceConfig{
		LoginMaxFailedAttempts: 3,
		LoginLockoutDuration:   time.Hour, // long enough not to expire mid-test
	})
	if _, aerr := svc.Register(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}

	// Trip the lock: the threshold-th wrong attempt locks the account. Every
	// failure still looks like a generic 401.
	for i := 0; i < 3; i++ {
		if _, aerr := svc.Login(ctx, "user@example.com", "wrong"); aerr == nil || aerr.Code != apperror.CodeUnauthorized {
			t.Fatalf("wrong attempt %d: want unauthorized, got %v", i+1, aerr)
		}
	}

	// Locked now. A caller who supplies the CORRECT password is told about the
	// lock (429 account_locked); a wrong password still gets the generic 401, so
	// the lock is not an oracle confirming the account exists.
	if _, aerr := svc.Login(ctx, "user@example.com", "password123"); aerr == nil || aerr.Code != apperror.CodeAccountLocked {
		t.Fatalf("locked + correct password: want account_locked, got %v", aerr)
	}
	if _, aerr := svc.Login(ctx, "user@example.com", "stillwrong"); aerr == nil || aerr.Code != apperror.CodeUnauthorized {
		t.Fatalf("locked + wrong password: want unauthorized (no lock oracle), got %v", aerr)
	}
}

func TestLoginLockoutExpires(t *testing.T) {
	ctx := context.Background()
	svc, _, _ := newTestServiceWith(ServiceConfig{
		LoginMaxFailedAttempts: 1,
		LoginLockoutDuration:   30 * time.Millisecond,
	})
	if _, aerr := svc.Register(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}

	// One wrong attempt trips the lock (threshold is 1).
	if _, aerr := svc.Login(ctx, "user@example.com", "wrong"); aerr == nil || aerr.Code != apperror.CodeUnauthorized {
		t.Fatalf("wrong attempt: want unauthorized, got %v", aerr)
	}
	if _, aerr := svc.Login(ctx, "user@example.com", "password123"); aerr == nil || aerr.Code != apperror.CodeAccountLocked {
		t.Fatalf("while locked: want account_locked, got %v", aerr)
	}

	// After the window lifts, the correct password logs in and clears the lock.
	time.Sleep(60 * time.Millisecond)
	if _, aerr := svc.Login(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("after lock expiry: want success, got %v", aerr)
	}
}

func TestDeleteAccount(t *testing.T) {
	ctx := context.Background()
	svc, mgr, _ := newTestService()
	if _, aerr := svc.Register(ctx, "user@example.com", "password123"); aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}
	login, aerr := svc.Login(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("setup Login: %v", aerr)
	}
	claims, err := mgr.ParseAccess(login.Access)
	if err != nil {
		t.Fatalf("parse access: %v", err)
	}
	userID := mustParseUUID(t, claims.UserID)

	if aerr := svc.DeleteAccount(ctx, userID); aerr != nil {
		t.Fatalf("DeleteAccount: unexpected error: %v", aerr)
	}
	// Deletion is idempotent.
	if aerr := svc.DeleteAccount(ctx, userID); aerr != nil {
		t.Fatalf("DeleteAccount (idempotent): unexpected error: %v", aerr)
	}
	// A deleted account can't log in, and its refresh token is dead.
	if _, login := svc.Login(ctx, "user@example.com", "password123"); login == nil {
		t.Fatalf("Login after delete: expected failure")
	}
	if _, refresh := svc.Refresh(ctx, login.Refresh); refresh == nil {
		t.Fatalf("Refresh after delete: expected failure")
	}
}
