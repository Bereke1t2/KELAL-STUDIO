package auth

import (
	"context"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
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

func newTestService() (*Service, *auth.Manager) {
	mgr := testManager()
	svc := NewService(NewMockRepository(), mgr, discardLogger(), true)
	return svc, mgr
}

func TestRegister(t *testing.T) {
	ctx := context.Background()
	svc, _ := newTestService()

	// Mixed-case + surrounding whitespace must normalize.
	tok, aerr := svc.Register(ctx, " User@Example.com ", "password123")
	if aerr != nil {
		t.Fatalf("Register: unexpected error: %v", aerr)
	}
	if tok.Access == "" || tok.Refresh == "" {
		t.Fatalf("Register: expected non-empty tokens, got %+v", tok)
	}

	// Re-registering the same (normalized) email is a conflict.
	_, aerr = svc.Register(ctx, "user@example.com", "password123")
	if aerr == nil || aerr.Code != apperror.CodeConflict {
		t.Fatalf("Register duplicate: want conflict, got %v", aerr)
	}
}

func TestLogin(t *testing.T) {
	ctx := context.Background()
	svc, _ := newTestService()
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
	svc, _ := newTestService()
	first, aerr := svc.Register(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
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
	svc, mgr := newTestService()
	reg, aerr := svc.Register(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}
	claims, err := mgr.ParseAccess(reg.Access)
	if err != nil {
		t.Fatalf("parse access: %v", err)
	}

	// Requesting a reset always reports success, even for an unknown email.
	if aerr := svc.RequestPasswordReset(ctx, "ghost@example.com"); aerr != nil {
		t.Fatalf("RequestPasswordReset unknown: want nil, got %v", aerr)
	}

	// A valid reset token lets the user set a new password.
	resetToken, err := mgr.GenerateReset(claims.UserID, time.Hour)
	if err != nil {
		t.Fatalf("GenerateReset: %v", err)
	}
	if aerr := svc.ConfirmPasswordReset(ctx, resetToken, "newpassword456"); aerr != nil {
		t.Fatalf("ConfirmPasswordReset: unexpected error: %v", aerr)
	}

	// Old password no longer works; new one does.
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

func TestDeleteAccount(t *testing.T) {
	ctx := context.Background()
	svc, mgr := newTestService()
	reg, aerr := svc.Register(ctx, "user@example.com", "password123")
	if aerr != nil {
		t.Fatalf("setup Register: %v", aerr)
	}
	claims, err := mgr.ParseAccess(reg.Access)
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
	if _, refresh := svc.Refresh(ctx, reg.Refresh); refresh == nil {
		t.Fatalf("Refresh after delete: expected failure")
	}
}
