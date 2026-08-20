package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ErrInvalidToken is returned for any token that fails to parse, has a bad
// signature, uses an unexpected signing method, or is expired. Callers map it
// to apperror.Unauthorized — deliberately opaque so it can't be used to probe.
var ErrInvalidToken = errors.New("auth: invalid token")

// Role values embedded in the access token (mirrors models.User.Role).
const (
	RoleUser  = "user"
	RoleAdmin = "admin"
)

// purposeReset tags a token minted for password reset so it can never be
// replayed as an access or refresh token (ParseReset rejects any other purpose).
const purposeReset = "pwreset"

// AccessClaims is the short-lived bearer token used to authorize API calls.
type AccessClaims struct {
	UserID string `json:"uid"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

// RefreshClaims is the long-lived token used only at /auth/refresh. TokenID is
// the DB primary key of the RefreshToken row (PRD §10.5), which is how rotation
// and reuse detection work: the auth feature looks the row up by this id, and a
// token whose row is already revoked signals reuse of a rotated token.
type RefreshClaims struct {
	UserID  string `json:"uid"`
	TokenID string `json:"jti"`
	jwt.RegisteredClaims
}

// ResetClaims is the short-lived, single-purpose token minted for a password
// reset (PRD §6.1). It is signed with the refresh secret but carries a distinct
// Purpose so it can't be swapped for a refresh token, and vice versa.
//
// FLAG: this token is stateless — it cannot be individually revoked before it
// expires. For V1 the short TTL bounds the window; a production hardening step
// is to make it single-use (store a jti hash and burn it on confirm). Tracked
// in docs/OPEN_QUESTIONS.md.
type ResetClaims struct {
	UserID  string `json:"uid"`
	Purpose string `json:"purpose"`
	jwt.RegisteredClaims
}

// Manager signs and verifies access + refresh tokens. Access and refresh use
// SEPARATE secrets so a leaked access secret can't mint refresh tokens.
type Manager struct {
	accessSecret  []byte
	refreshSecret []byte
	accessTTL     time.Duration
	refreshTTL    time.Duration
}

// NewManager takes the two secrets and TTLs directly (not the config struct) so
// this package stays decoupled from config.
func NewManager(accessSecret, refreshSecret string, accessTTL, refreshTTL time.Duration) *Manager {
	return &Manager{
		accessSecret:  []byte(accessSecret),
		refreshSecret: []byte(refreshSecret),
		accessTTL:     accessTTL,
		refreshTTL:    refreshTTL,
	}
}

// GenerateAccess mints a signed access token for a user + role.
func (m *Manager) GenerateAccess(userID, role string) (string, error) {
	now := time.Now()
	claims := AccessClaims{
		UserID: userID,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(m.accessTTL)),
			Subject:   userID,
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(m.accessSecret)
}

// GenerateRefresh mints a signed refresh token bound to a DB token id, and
// returns the token plus its absolute expiry (to persist as expires_at).
func (m *Manager) GenerateRefresh(userID, tokenID string) (token string, expiresAt time.Time, err error) {
	now := time.Now()
	expiresAt = now.Add(m.refreshTTL)
	claims := RefreshClaims{
		UserID:  userID,
		TokenID: tokenID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
			Subject:   userID,
		},
	}
	token, err = jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(m.refreshSecret)
	return token, expiresAt, err
}

// ParseAccess verifies an access token and returns its claims.
func (m *Manager) ParseAccess(token string) (*AccessClaims, error) {
	claims := &AccessClaims{}
	if err := parse(token, claims, m.accessSecret); err != nil {
		return nil, err
	}
	return claims, nil
}

// ParseRefresh verifies a refresh token and returns its claims.
func (m *Manager) ParseRefresh(token string) (*RefreshClaims, error) {
	claims := &RefreshClaims{}
	if err := parse(token, claims, m.refreshSecret); err != nil {
		return nil, err
	}
	return claims, nil
}

// GenerateReset mints a short-lived password-reset token for a user. It is
// signed with the refresh secret and purpose-tagged so ParseReset is the only
// method that will accept it.
func (m *Manager) GenerateReset(userID string, ttl time.Duration) (string, error) {
	now := time.Now()
	claims := ResetClaims{
		UserID:  userID,
		Purpose: purposeReset,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
			Subject:   userID,
		},
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(m.refreshSecret)
}

// ParseReset verifies a password-reset token and returns the user id it was
// minted for. A token that parses but carries the wrong purpose (e.g. a raw
// refresh token) is rejected — the purpose check is what stops cross-use.
func (m *Manager) ParseReset(token string) (userID string, err error) {
	claims := &ResetClaims{}
	if err := parse(token, claims, m.refreshSecret); err != nil {
		return "", err
	}
	if claims.Purpose != purposeReset {
		return "", ErrInvalidToken
	}
	return claims.UserID, nil
}

// parse verifies signature (HS256 only), expiry, and method, collapsing every
// failure into ErrInvalidToken so callers can't distinguish "expired" from
// "forged" from "malformed".
func parse(token string, claims jwt.Claims, secret []byte) error {
	_, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("%w: unexpected signing method %v", ErrInvalidToken, t.Header["alg"])
		}
		return secret, nil
	}, jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}))
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidToken, err)
	}
	return nil
}
