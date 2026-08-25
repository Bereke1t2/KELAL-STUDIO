package auth

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"log/slog"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/auth"

	// aliased so the many `email string` parameters below don't shadow the package.
	mail "github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/email"
)

// Feature-level policy defaults, applied by NewService when ServiceConfig leaves
// a field zero. They are deliberately conservative: short-lived tokens and a
// lockout window long enough to blunt online guessing without stranding a
// fat-fingered legitimate user.
const (
	defaultVerificationTTL        = 24 * time.Hour
	defaultPasswordResetTTL       = time.Hour
	defaultLoginMaxFailedAttempts = 10
	defaultLoginLockoutDuration   = 15 * time.Minute
)

// ServiceConfig carries the auth policy knobs the service needs. It is a
// feature-local struct (not platform/config) so the service stays decoupled from
// how configuration is loaded — module.go maps config.Config onto it.
type ServiceConfig struct {
	// PublicBaseURL is the origin the verification / reset links point at (the
	// app or web front door that captures the token). No trailing slash.
	PublicBaseURL string

	VerificationTTL        time.Duration
	PasswordResetTTL       time.Duration
	LoginMaxFailedAttempts int
	LoginLockoutDuration   time.Duration
}

// withDefaults returns a copy with any zero field replaced by its default.
func (c ServiceConfig) withDefaults() ServiceConfig {
	if c.VerificationTTL <= 0 {
		c.VerificationTTL = defaultVerificationTTL
	}
	if c.PasswordResetTTL <= 0 {
		c.PasswordResetTTL = defaultPasswordResetTTL
	}
	if c.LoginMaxFailedAttempts <= 0 {
		c.LoginMaxFailedAttempts = defaultLoginMaxFailedAttempts
	}
	if c.LoginLockoutDuration <= 0 {
		c.LoginLockoutDuration = defaultLoginLockoutDuration
	}
	return c
}

// Service holds the auth use cases. Each public method is ONE use case and
// returns (result, *apperror.Error) — failures are values the delivery layer
// renders, never panics. The service depends only on the Repository port, the
// auth PRIMITIVES (hashing, JWT), and the email Sender port — never on GORM or gin.
type Service struct {
	repo   Repository
	jwt    *auth.Manager
	log    *slog.Logger
	mailer mail.Sender
	cfg    ServiceConfig

	// dummyHash is a valid bcrypt hash compared against on login for unknown
	// emails, so a missing account costs the same time as a wrong password —
	// closing the timing side-channel that would otherwise enumerate users.
	dummyHash string
}

// NewService wires the use cases. mailer must be non-nil (module.New supplies a
// dev LogSender when none is configured). Zero-valued cfg fields take their
// package defaults.
func NewService(repo Repository, jwtMgr *auth.Manager, log *slog.Logger, mailer mail.Sender, cfg ServiceConfig) *Service {
	// Precompute the timing-equalizer hash once at construction. bcrypt only
	// fails on absurd inputs; if it ever did, CheckPassword against "" still
	// returns false — correctness holds, only the timing guarantee weakens.
	dummy, _ := auth.HashPassword("timing-equalizer-not-a-real-credential")
	return &Service{
		repo:      repo,
		jwt:       jwtMgr,
		log:       log,
		mailer:    mailer,
		cfg:       cfg.withDefaults(),
		dummyHash: dummy,
	}
}

// Register creates an account and sends a verification email (PRD §11). It does
// NOT establish a session: the caller must verify their email, then log in. The
// result is {user_id, verification_sent}. A duplicate email is a 409 (register
// intentionally reveals this — anti-enumeration applies to login/reset, not to
// telling a user their email is already taken).
func (s *Service) Register(ctx context.Context, email, password string) (RegisterResult, *apperror.Error) {
	email = normalizeEmail(email)
	hash, err := auth.HashPassword(password)
	if err != nil {
		return RegisterResult{}, apperror.Internal(err)
	}
	u := &models.User{
		Email:        email,
		PasswordHash: hash,
		Role:         models.RoleUser,
	}
	if err := s.repo.CreateUser(ctx, u); err != nil {
		if errors.Is(err, ErrEmailTaken) {
			return RegisterResult{}, apperror.Conflict("that email is already registered")
		}
		return RegisterResult{}, apperror.Internal(err)
	}
	sent := s.sendVerificationEmail(ctx, u)
	return RegisterResult{UserID: u.ID.String(), VerificationSent: sent}, nil
}

// Login verifies credentials and establishes a session. Every credential-failure
// path returns the SAME generic message and status (PRD §6.1) — the response
// must not reveal whether the email exists or the password was wrong. On too many
// failures the account is temporarily locked (PRD §6.1).
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

	// Always run the comparison (uniform timing) before branching on lock state.
	locked := u.LockedUntil != nil && time.Now().Before(*u.LockedUntil)
	ok := auth.CheckPassword(u.PasswordHash, password)

	if locked {
		// Reveal the lock ONLY to a caller who already proved the password —
		// otherwise the lock would be an oracle confirming the account exists.
		// We do not increment or extend the lock here (guards against a caller
		// prolonging their own lockout, PRD §6.1).
		if ok {
			return Tokens{}, apperror.AccountLocked("too many failed attempts; try again later")
		}
		return Tokens{}, invalidCredentials()
	}

	if !ok {
		s.recordFailedLogin(ctx, u.ID)
		return Tokens{}, invalidCredentials()
	}

	// Success: clear any accumulated failures/lock (best-effort) and issue.
	if u.FailedLoginAttempts > 0 || u.LockedUntil != nil {
		if err := s.repo.ResetFailedLoginAttempts(ctx, u.ID); err != nil {
			s.log.Error("failed to reset login attempts", "user_id", u.ID.String(), "error", err.Error())
		}
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
// exists it mints a version-pinned reset token and emails the link.
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

	token, err := s.jwt.GenerateReset(u.ID.String(), u.TokenVersion, s.cfg.PasswordResetTTL)
	if err != nil {
		s.log.Error("password reset token generation failed",
			"user_id", u.ID.String(), "error", err.Error())
		return nil
	}

	link := s.cfg.PublicBaseURL + "/reset-password?token=" + url.QueryEscape(token)
	msg := mail.Message{
		To:      u.Email,
		Subject: "Reset your Kelal Studio password",
		Body: "We received a request to reset your Kelal Studio password.\n\n" +
			"Reset it here:\n" + link + "\n\n" +
			"This link expires in " + humanDuration(s.cfg.PasswordResetTTL) + ".\n" +
			"If you didn't request this, you can safely ignore this email.",
	}
	if err := s.mailer.Send(ctx, msg); err != nil {
		// Still return nil (anti-enumeration); the user can retry.
		s.log.Error("password reset email send failed", "user_id", u.ID.String(), "error", err.Error())
	}
	return nil
}

// ConfirmPasswordReset validates the reset token and sets a new password, then
// revokes all existing sessions so a leaked token can't outlive the reset. The
// token is single-use: it carries the user's TokenVersion, and the repository
// only applies the change while that still matches — the same UPDATE bumps the
// version, so a replay (or a password changed by another route) fails.
func (s *Service) ConfirmPasswordReset(ctx context.Context, token, newPassword string) *apperror.Error {
	userIDStr, version, err := s.jwt.ParseReset(token)
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
	if err := s.repo.UpdateUserPassword(ctx, userID, version, hash); err != nil {
		if errors.Is(err, ErrUserNotFound) {
			// Missing user OR stale version (used token) — same opaque response.
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

// VerifyEmail consumes an email-verification token and marks the account
// verified (PRD §6.1). It is idempotent — verifying an already-verified account
// succeeds. Any bad/expired token, or a token for a vanished account, is the
// same opaque 401.
func (s *Service) VerifyEmail(ctx context.Context, token string) *apperror.Error {
	userIDStr, err := s.jwt.ParseVerify(token)
	if err != nil {
		return apperror.Unauthorized("invalid or expired verification token")
	}
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return apperror.Unauthorized("invalid or expired verification token")
	}
	if err := s.repo.MarkEmailVerified(ctx, userID); err != nil {
		if errors.Is(err, ErrUserNotFound) {
			return apperror.Unauthorized("invalid or expired verification token")
		}
		return apperror.Internal(err)
	}
	return nil
}

// ResendVerification re-sends a verification email. Like RequestPasswordReset it
// ALWAYS reports success (anti-enumeration): the caller can't learn whether the
// email is registered or already verified. It is unauthenticated by design —
// a user who can't log in until verified still needs to be able to re-request.
func (s *Service) ResendVerification(ctx context.Context, email string) *apperror.Error {
	email = normalizeEmail(email)
	u, err := s.repo.FindUserByEmail(ctx, email)
	if err != nil {
		if !errors.Is(err, ErrUserNotFound) {
			s.log.Error("resend verification lookup failed", "error", err.Error())
		}
		return nil
	}
	if u.EmailVerifiedAt != nil {
		// Already verified: send nothing, but the caller can't tell (same 200).
		return nil
	}
	s.sendVerificationEmail(ctx, u)
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
// the one it replaced (nil for a fresh login). The access token carries the
// account's current verification state so the generation gate can read it.
func (s *Service) issueSession(ctx context.Context, u *models.User, rotatedFrom *uuid.UUID) (Tokens, *apperror.Error) {
	access, err := s.jwt.GenerateAccess(u.ID.String(), string(u.Role), u.EmailVerifiedAt != nil)
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

// sendVerificationEmail mints a verification token and emails the link. It
// reports whether the message reached the mailer; failures are logged, not
// surfaced (registration/resend still succeed — the user can resend).
func (s *Service) sendVerificationEmail(ctx context.Context, u *models.User) bool {
	token, err := s.jwt.GenerateVerify(u.ID.String(), s.cfg.VerificationTTL)
	if err != nil {
		s.log.Error("verification token generation failed", "user_id", u.ID.String(), "error", err.Error())
		return false
	}
	link := s.cfg.PublicBaseURL + "/verify-email?token=" + url.QueryEscape(token)
	msg := mail.Message{
		To:      u.Email,
		Subject: "Verify your Kelal Studio email",
		Body: "Welcome to Kelal Studio!\n\n" +
			"Verify your email address to start creating:\n" + link + "\n\n" +
			"This link expires in " + humanDuration(s.cfg.VerificationTTL) + ".\n" +
			"If you didn't create an account, you can safely ignore this email.",
	}
	if err := s.mailer.Send(ctx, msg); err != nil {
		s.log.Error("verification email send failed", "user_id", u.ID.String(), "error", err.Error())
		return false
	}
	return true
}

// recordFailedLogin increments the failure counter and locks the account once it
// reaches the configured threshold. Best-effort: a storage error is logged, not
// returned, so it can't turn a wrong password into a 500 (and thereby leak that
// the account exists).
func (s *Service) recordFailedLogin(ctx context.Context, userID uuid.UUID) {
	n, err := s.repo.IncrementFailedLoginAttempts(ctx, userID)
	if err != nil {
		s.log.Error("failed to record failed login", "user_id", userID.String(), "error", err.Error())
		return
	}
	if n >= s.cfg.LoginMaxFailedAttempts {
		if err := s.repo.LockUser(ctx, userID, time.Now().Add(s.cfg.LoginLockoutDuration)); err != nil {
			s.log.Error("failed to lock account", "user_id", userID.String(), "error", err.Error())
			return
		}
		s.log.Warn("account locked after repeated failed logins", "user_id", userID.String())
	}
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

// humanDuration renders a TTL for an email body ("24 hours", "1 hour"). Kept
// deliberately coarse — these are onboarding emails, not audit logs.
func humanDuration(d time.Duration) string {
	if d%time.Hour == 0 {
		h := int(d / time.Hour)
		if h == 1 {
			return "1 hour"
		}
		return strconv.Itoa(h) + " hours"
	}
	m := int(d / time.Minute)
	if m == 1 {
		return "1 minute"
	}
	return strconv.Itoa(m) + " minutes"
}
