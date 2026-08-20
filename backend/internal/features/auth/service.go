package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"
)

// passwordResetTTL bounds how long a reset link is valid. It is a feature-level
// policy (not in config) and deliberately short — the stateless reset token
// can't be individually revoked, so the TTL is the safety window (see
// auth.ResetClaims and docs/OPEN_QUESTIONS.md).
const passwordResetTTL = time.Hour

// Service holds the auth use cases. Each public method is ONE use case and
// returns (result, *apperror.Error) — failures are values the delivery layer
// renders, never panics. The service depends only on the Repository port and
// the auth PRIMITIVES (hashing, JWT), never on GORM or gin.
type Service struct {
	repo Repository
	jwt  *auth.Manager
	log  *slog.Logger

	// logResetTokens is true only outside production. With no email service
	// wired yet, dev logs the reset token so the flow is testable end-to-end;
	// production must never log it (see RequestPasswordReset).
	logResetTokens bool

	// dummyHash is a valid bcrypt hash compared against on login for unknown
	// emails, so a missing account costs the same time as a wrong password —
	// closing the timing side-channel that would otherwise enumerate users.
	dummyHash string
}

// NewService wires the use cases. logResetTokens should be false in production.
func NewService(repo Repository, jwtMgr *auth.Manager, log *slog.Logger, logResetTokens bool) *Service {
	// Precompute the timing-equalizer hash once at construction. bcrypt only
	// fails on absurd inputs; if it ever did, CheckPassword against "" still
	// returns false — correctness holds, only the timing guarantee weakens.
	dummy, _ := auth.HashPassword("timing-equalizer-not-a-real-credential")
	return &Service{
		repo:           repo,
		jwt:            jwtMgr,
		log:            log,
		logResetTokens: logResetTokens,
		dummyHash:      dummy,
	}
}

// Register creates an account and immediately establishes a session.
//
// FLAG (contract-vs-PRD divergence, see docs/OPEN_QUESTIONS.md): the contract
// (openapi.yaml) returns AuthTokens here, but PRD §11 specifies an
// email-verify-first flow returning {user_id, verification_sent}. V1 serves the
// contract shape so the already-generated mobile client isn't broken;
// User.EmailVerifiedAt still exists and stays nil until a verification flow is
// built. TODO(auth): reconcile once email delivery is wired.
func (s *Service) Register(ctx context.Context, email, password string) (Tokens, *apperror.Error) {
	email = normalizeEmail(email)
	hash, err := auth.HashPassword(password)
	if err != nil {
		return Tokens{}, apperror.Internal(err)
	}
	u := &models.User{
		Email:        email,
		PasswordHash: hash,
		Role:         models.RoleUser,
	}
	if err := s.repo.CreateUser(ctx, u); err != nil {
		if errors.Is(err, ErrEmailTaken) {
			return Tokens{}, apperror.Conflict("that email is already registered")
		}
		return Tokens{}, apperror.Internal(err)
	}
	return s.issueSession(ctx, u, nil)
}

// Login verifies credentials and establishes a session. Every failure path
// returns the SAME generic message and status (PRD §6.1): the response must not
// reveal whether the email exists or the password was wrong.
func (s *Service) Login(ctx context.Context, email, password string) (Tokens, *apperror.Error) {
	email = normalizeEmail(email)
	u, err := s.repo.FindUserByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, ErrUserNotFound) {
			// Equalize timing: run a bcrypt comparison even with no account,
			// so "unknown email" and "wrong password" take the same time.
			auth.CheckPassword(s.dummyHash, password)
			return Tokens{}, invalidCredentials()
		}
		return Tokens{}, apperror.Internal(err)
	}
	if !auth.CheckPassword(u.PasswordHash, password) {
		return Tokens{}, invalidCredentials()
	}
	return s.issueSession(ctx, u, nil)
}

// Refresh rotates a refresh token: the presented token is revoked and a new
// pair is issued, linked via RotatedFromID. Reuse of an already-revoked token
// is treated as compromise — the whole chain is revoked and re-auth is forced
// (PRD §6.1). No branch reveals which specific check failed.
func (s *Service) Refresh(ctx context.Context, refreshToken string) (Tokens, *apperror.Error) {
	claims, err := s.jwt.ParseRefresh(refreshToken)
	if err != nil {
		return Tokens{}, apperror.Unauthorized("invalid or expired refresh token")
	}
	tokenID, err := uuid.Parse(claims.TokenID)
	if err != nil {
		return Tokens{}, apperror.Unauthorized("invalid or expired refresh token")
	}

	rt, err := s.repo.FindRefreshTokenByID(ctx, tokenID)
	if err != nil {
		if errors.Is(err, ErrRefreshTokenNotFound) {
			return Tokens{}, apperror.Unauthorized("invalid or expired refresh token")
		}
		return Tokens{}, apperror.Internal(err)
	}

	// Reuse detection: a token whose row is already revoked is a superseded
	// (rotated) token being replayed → assume theft, revoke the entire chain.
	if rt.RevokedAt != nil {
		if err := s.repo.RevokeAllUserRefreshTokens(ctx, rt.UserID); err != nil {
			s.log.Error("failed to revoke token chain on reuse detection",
				"user_id", rt.UserID.String(), "error", err.Error())
		}
		s.log.Warn("refresh token reuse detected; chain revoked", "user_id", rt.UserID.String())
		return Tokens{}, apperror.Unauthorized("invalid or expired refresh token")
	}

	// Defense in depth: the stored hash must match the presented token. Guards
	// against a forged jti pointing at someone else's live row.
	if rt.TokenHash != hashToken(refreshToken) {
		return Tokens{}, apperror.Unauthorized("invalid or expired refresh token")
	}
	if time.Now().After(rt.ExpiresAt) {
		return Tokens{}, apperror.Unauthorized("invalid or expired refresh token")
	}

	// Rotate: revoke the presented token, then mint a new pair linked to it.
	if err := s.repo.RevokeRefreshToken(ctx, rt.ID); err != nil {
		return Tokens{}, apperror.Internal(err)
	}
	u, err := s.repo.FindUserByID(ctx, rt.UserID)
	if err != nil {
		if errors.Is(err, ErrUserNotFound) {
			// Account was deleted after the token was minted.
			return Tokens{}, apperror.Unauthorized("invalid or expired refresh token")
		}
		return Tokens{}, apperror.Internal(err)
	}
	return s.issueSession(ctx, u, &rt.ID)
}

// RequestPasswordReset ALWAYS reports success to the caller (anti-enumeration,
// PRD §6.1) — the returned error is always nil. Internally, if the account
// exists it mints a reset token; delivery is not yet wired (FLAG below).
func (s *Service) RequestPasswordReset(ctx context.Context, email string) *apperror.Error {
	email = normalizeEmail(email)
	u, err := s.repo.FindUserByEmail(ctx, email)
	if err != nil {
		if !errors.Is(err, ErrUserNotFound) {
			// A real lookup error is worth logging, but we still return 200 so
			// the client can't distinguish it from "no such account".
			s.log.Error("password reset lookup failed", "error", err.Error())
		}
		return nil
	}

	token, err := s.jwt.GenerateReset(u.ID.String(), passwordResetTTL)
	if err != nil {
		s.log.Error("password reset token generation failed",
			"user_id", u.ID.String(), "error", err.Error())
		return nil
	}

	// FLAG: no email delivery service exists yet (docs/OPEN_QUESTIONS.md). In
	// dev we log the token so the reset flow is testable end-to-end; production
	// MUST send it by email and MUST NOT log it. TODO(auth): wire delivery.
	if s.logResetTokens {
		s.log.Info("password reset requested (DEV ONLY: token logged — wire email delivery)",
			"user_id", u.ID.String(), "reset_token", token)
	} else {
		s.log.Warn("password reset requested but email delivery is not implemented",
			"user_id", u.ID.String())
	}
	return nil
}

// ConfirmPasswordReset validates the reset token and sets a new password, then
// revokes all existing sessions so a leaked token can't outlive the reset.
func (s *Service) ConfirmPasswordReset(ctx context.Context, token, newPassword string) *apperror.Error {
	userIDStr, err := s.jwt.ParseReset(token)
	if err != nil {
		return apperror.Unauthorized("invalid or expired reset token")
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return apperror.Unauthorized("invalid or expired reset token")
	}

	hash, err := auth.HashPassword(newPassword)
	if err != nil {
		return apperror.Internal(err)
	}
	if err := s.repo.UpdateUserPassword(ctx, userID, hash); err != nil {
		if errors.Is(err, ErrUserNotFound) {
			// Don't reveal that the account is gone — same opaque response.
			return apperror.Unauthorized("invalid or expired reset token")
		}
		return apperror.Internal(err)
	}

	// Force re-login everywhere after a password change (best effort).
	if err := s.repo.RevokeAllUserRefreshTokens(ctx, userID); err != nil {
		s.log.Error("failed to revoke sessions after password reset",
			"user_id", userID.String(), "error", err.Error())
	}
	return nil
}

// DeleteAccount soft-deletes the authenticated user and revokes their sessions
// (PRD §6.1). It is idempotent: deleting an already-deleted account still
// reports success, since the caller is authenticated as that account.
func (s *Service) DeleteAccount(ctx context.Context, userID uuid.UUID) *apperror.Error {
	if err := s.repo.RevokeAllUserRefreshTokens(ctx, userID); err != nil {
		return apperror.Internal(err)
	}
	if err := s.repo.SoftDeleteUser(ctx, userID); err != nil {
		if errors.Is(err, ErrUserNotFound) {
			return nil
		}
		return apperror.Internal(err)
	}
	return nil
}

// ── helpers ────────────────────────────────────────────────────────────────

// issueSession mints an access token and a rotated refresh token, persisting
// the refresh row (only its hash is stored). rotatedFrom links the new token to
// the one it replaced (nil for a fresh login/registration).
func (s *Service) issueSession(ctx context.Context, u *models.User, rotatedFrom *uuid.UUID) (Tokens, *apperror.Error) {
	access, err := s.jwt.GenerateAccess(u.ID.String(), string(u.Role))
	if err != nil {
		return Tokens{}, apperror.Internal(err)
	}

	// Generate the row id first so it can be embedded in the signed token (jti);
	// the model's BeforeCreate hook only assigns an id when one isn't set, so
	// this pre-set id is preserved.
	tokenID := uuid.New()
	refresh, expiresAt, err := s.jwt.GenerateRefresh(u.ID.String(), tokenID.String())
	if err != nil {
		return Tokens{}, apperror.Internal(err)
	}

	rt := &models.RefreshToken{
		Base:          models.Base{ID: tokenID},
		UserID:        u.ID,
		TokenHash:     hashToken(refresh),
		RotatedFromID: rotatedFrom,
		ExpiresAt:     expiresAt,
	}
	if err := s.repo.CreateRefreshToken(ctx, rt); err != nil {
		return Tokens{}, apperror.Internal(err)
	}
	return Tokens{Access: access, Refresh: refresh}, nil
}

// invalidCredentials is the single generic auth failure used for both unknown
// email and wrong password (PRD §6.1) — same code, status, and message.
func invalidCredentials() *apperror.Error {
	return apperror.Unauthorized("invalid email or password")
}

// normalizeEmail lower-cases and trims so lookups and the unique index agree.
func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

// hashToken returns the hex SHA-256 of a token. Only the hash is ever stored,
// so a database leak doesn't expose usable refresh tokens.
func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
