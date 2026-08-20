// Package auth holds the shared authentication PRIMITIVES — password hashing
// and JWT signing/verification. It is deliberately free of business logic: the
// auth *feature* (internal/features/auth) owns registration, login, and
// refresh-token rotation/reuse policy; this package just gives it safe, tested
// building blocks that any feature can reuse.
package auth

import "golang.org/x/crypto/bcrypt"

// DefaultCost is the bcrypt cost. 12 is a deliberate step above bcrypt's
// default (10) — a reasonable 2026 floor for password hashing.
const DefaultCost = 12

// HashPassword returns the bcrypt hash of a plaintext password.
func HashPassword(plain string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(plain), DefaultCost)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// CheckPassword reports whether plain matches the stored bcrypt hash. It runs
// in constant time relative to the hash (bcrypt property), which is why login
// must always call this even for unknown emails — see the auth feature.
func CheckPassword(hash, plain string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
}
