package admin

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/models"
	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// These tests run entirely on the in-memory repository — no Postgres, no
// network. Because admin aggregates and mutates rows other features own, the mock
// is SEEDED directly (tests live in-package): we populate its users/flags/
// generations maps, exercise a use case, and assert on both the result and the
// audit log the mutating use cases must have written. The helpers here
// (discardLogger, ptr, seedFlag, seedUser) are shared with handler_test.go.

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func ptr(n int) *int { return &n }

// newTestService builds a service over a freshly-seeded mock, returning both so a
// test can seed inputs and inspect the recorded audit rows via the concrete mock.
func newTestService() (*Service, *mockRepository) {
	repo := newMockRepository()
	return NewService(repo, discardLogger()), repo
}

// seedFlag inserts a moderation flag into the mock, optionally pre-reviewed.
func seedFlag(repo *mockRepository, reviewed bool) models.ModerationFlag {
	f := models.ModerationFlag{
		Base:          models.Base{ID: uuid.New()},
		UserID:        uuid.New(),
		InputSnapshot: "flagged input",
		Reason:        "test reason",
		CreatedAt:     time.Now(),
	}
	if reviewed {
		now := time.Now()
		reviewer := uuid.New()
		f.ReviewedAt = &now
		f.ReviewedByAdminID = &reviewer
	}
	repo.flags[f.ID] = f
	return f
}

// seedUser inserts a user (no quota overrides) into the mock.
func seedUser(repo *mockRepository) models.User {
	u := models.User{Base: models.Base{ID: uuid.New()}, Email: "u@example.com", Role: models.RoleUser}
	repo.users[u.ID] = u
	return u
}

func TestUsageCounts(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()

	seedUser(repo)
	seedUser(repo)
	repo.generations = []models.GenerationRecord{
		{Type: models.GenerationText},
		{Type: models.GenerationText},
		{Type: models.GenerationImage},
	}
	seedFlag(repo, false) // pending
	seedFlag(repo, true)  // reviewed

	sum, aerr := svc.Usage(ctx)
	if aerr != nil {
		t.Fatalf("Usage: unexpected error: %v", aerr)
	}
	if sum.TotalUsers != 2 {
		t.Errorf("TotalUsers: want 2, got %d", sum.TotalUsers)
	}
	if sum.TotalGenerations != 3 || sum.TextGenerations != 2 || sum.ImageGenerations != 1 || sum.VideoGenerations != 0 {
		t.Errorf("generation counts wrong: %+v", sum)
	}
	if sum.TotalFlags != 2 || sum.PendingFlags != 1 {
		t.Errorf("flag counts: want total=2 pending=1, got total=%d pending=%d", sum.TotalFlags, sum.PendingFlags)
	}
}

func TestListFlagsPendingFilter(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()
	seedFlag(repo, false)
	seedFlag(repo, false)
	seedFlag(repo, true)

	all, aerr := svc.ListFlags(ctx, false)
	if aerr != nil {
		t.Fatalf("ListFlags all: %v", aerr)
	}
	if len(all) != 3 {
		t.Fatalf("ListFlags all: want 3, got %d", len(all))
	}

	pending, aerr := svc.ListFlags(ctx, true)
	if aerr != nil {
		t.Fatalf("ListFlags pending: %v", aerr)
	}
	if len(pending) != 2 {
		t.Fatalf("ListFlags pending: want 2, got %d", len(pending))
	}
	for _, f := range pending {
		if f.ReviewedAt != nil {
			t.Fatalf("ListFlags pending: returned a reviewed flag: %+v", f)
		}
	}
}

func TestReviewFlagHappyPath(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()
	adminID := uuid.New()
	flag := seedFlag(repo, false)

	reviewed, aerr := svc.ReviewFlag(ctx, flag.ID, adminID)
	if aerr != nil {
		t.Fatalf("ReviewFlag: unexpected error: %v", aerr)
	}
	if reviewed.ReviewedAt == nil {
		t.Fatalf("ReviewFlag: expected reviewed_at to be set")
	}
	if reviewed.ReviewedByAdminID == nil || *reviewed.ReviewedByAdminID != adminID {
		t.Fatalf("ReviewFlag: reviewer not recorded: %+v", reviewed.ReviewedByAdminID)
	}

	// The mutation MUST have written exactly one audit row naming the flag.
	if len(repo.auditLogs) != 1 {
		t.Fatalf("ReviewFlag: want 1 audit row, got %d", len(repo.auditLogs))
	}
	a := repo.auditLogs[0]
	if a.AdminUserID != adminID || a.Action != auditActionReviewFlag || a.TargetRef != "flag:"+flag.ID.String() {
		t.Fatalf("ReviewFlag: audit row wrong: %+v", a)
	}
	// The stored flag reflects the review.
	if stored := repo.flags[flag.ID]; stored.ReviewedAt == nil {
		t.Fatalf("ReviewFlag: stored flag not updated")
	}
}

func TestReviewFlagNotFound(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()

	_, aerr := svc.ReviewFlag(ctx, uuid.New(), uuid.New())
	if aerr == nil || aerr.Code != apperror.CodeNotFound {
		t.Fatalf("ReviewFlag unknown: want not_found, got %v", aerr)
	}
	if len(repo.auditLogs) != 0 {
		t.Fatalf("ReviewFlag unknown: must not write an audit row, got %d", len(repo.auditLogs))
	}
}

// Re-reviewing an already-adjudicated flag is a 409 Conflict, and it must NOT
// overwrite the original reviewer or write a second audit row.
func TestReviewFlagAlreadyReviewedIsConflict(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()
	flag := seedFlag(repo, true)
	originalReviewer := *flag.ReviewedByAdminID

	_, aerr := svc.ReviewFlag(ctx, flag.ID, uuid.New())
	if aerr == nil || aerr.Code != apperror.CodeConflict {
		t.Fatalf("re-review: want conflict, got %v", aerr)
	}
	if len(repo.auditLogs) != 0 {
		t.Fatalf("re-review: must not write an audit row, got %d", len(repo.auditLogs))
	}
	if got := *repo.flags[flag.ID].ReviewedByAdminID; got != originalReviewer {
		t.Fatalf("re-review: original reviewer was overwritten: %s → %s", originalReviewer, got)
	}
}

// A second reviewer that races PAST the service's sequential pre-check — both
// admins read the flag while it was still pending — must still lose at the
// repository: the flag keeps its first reviewer and no second audit row is
// written. This exercises the atomic conditional claim directly on the port,
// which the sequential pre-check above can't reach.
func TestReviewFlagRepositoryRejectsConcurrentSecondReviewer(t *testing.T) {
	ctx := context.Background()
	repo := newMockRepository()
	flag := seedFlag(repo, false)
	first, second := uuid.New(), uuid.New()
	now := time.Now()

	f1 := flag
	f1.ReviewedByAdminID = &first
	f1.ReviewedAt = &now
	if err := repo.ReviewFlag(ctx, &f1, &models.AdminAuditLog{
		AdminUserID: first, Action: auditActionReviewFlag, TargetRef: targetRef("flag", flag.ID), CreatedAt: now,
	}); err != nil {
		t.Fatalf("first review: unexpected error: %v", err)
	}

	// Second reviewer acts on the same stale, still-pending read.
	f2 := flag
	f2.ReviewedByAdminID = &second
	f2.ReviewedAt = &now
	err := repo.ReviewFlag(ctx, &f2, &models.AdminAuditLog{
		AdminUserID: second, Action: auditActionReviewFlag, TargetRef: targetRef("flag", flag.ID), CreatedAt: now,
	})
	if !errors.Is(err, ErrFlagAlreadyReviewed) {
		t.Fatalf("second review: want ErrFlagAlreadyReviewed, got %v", err)
	}

	if got := *repo.flags[flag.ID].ReviewedByAdminID; got != first {
		t.Fatalf("second review overwrote the first reviewer: %s → %s", first, got)
	}
	if len(repo.auditLogs) != 1 {
		t.Fatalf("want exactly 1 audit row (only the first review), got %d", len(repo.auditLogs))
	}
}

func TestSetUserLimitsHappyPath(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()
	adminID := uuid.New()
	user := seedUser(repo)

	// Zero is a real value ("block all"), distinct from nil ("no override").
	updated, aerr := svc.SetUserLimits(ctx, user.ID, adminID, LimitsInput{
		DailyTextQuota:  ptr(10),
		DailyImageQuota: ptr(0),
	})
	if aerr != nil {
		t.Fatalf("SetUserLimits: unexpected error: %v", aerr)
	}
	if updated.DailyTextQuota == nil || *updated.DailyTextQuota != 10 {
		t.Fatalf("SetUserLimits: text quota not applied: %+v", updated.DailyTextQuota)
	}
	if updated.DailyImageQuota == nil || *updated.DailyImageQuota != 0 {
		t.Fatalf("SetUserLimits: image quota (zero is valid) not applied: %+v", updated.DailyImageQuota)
	}

	if len(repo.auditLogs) != 1 {
		t.Fatalf("SetUserLimits: want 1 audit row, got %d", len(repo.auditLogs))
	}
	a := repo.auditLogs[0]
	if a.AdminUserID != adminID || a.Action != auditActionSetUserLimits || a.TargetRef != "user:"+user.ID.String() {
		t.Fatalf("SetUserLimits: audit row wrong: %+v", a)
	}
	if stored := repo.users[user.ID]; stored.DailyTextQuota == nil || *stored.DailyTextQuota != 10 {
		t.Fatalf("SetUserLimits: not persisted")
	}
}

// A nil field clears an existing override (falls back to the global default),
// while a sibling value is applied in the same call.
func TestSetUserLimitsClearsOverride(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()
	user := seedUser(repo)
	user.DailyTextQuota = ptr(5)
	repo.users[user.ID] = user

	updated, aerr := svc.SetUserLimits(ctx, user.ID, uuid.New(), LimitsInput{
		DailyTextQuota:  nil,
		DailyImageQuota: ptr(7),
	})
	if aerr != nil {
		t.Fatalf("SetUserLimits clear: unexpected error: %v", aerr)
	}
	if updated.DailyTextQuota != nil {
		t.Fatalf("SetUserLimits clear: text override should be nil, got %d", *updated.DailyTextQuota)
	}
	if updated.DailyImageQuota == nil || *updated.DailyImageQuota != 7 {
		t.Fatalf("SetUserLimits clear: image override not applied")
	}
	if stored := repo.users[user.ID]; stored.DailyTextQuota != nil {
		t.Fatalf("SetUserLimits clear: override not cleared in store")
	}
}

func TestSetUserLimitsNotFound(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()

	_, aerr := svc.SetUserLimits(ctx, uuid.New(), uuid.New(), LimitsInput{DailyTextQuota: ptr(1)})
	if aerr == nil || aerr.Code != apperror.CodeNotFound {
		t.Fatalf("SetUserLimits unknown: want not_found, got %v", aerr)
	}
	if len(repo.auditLogs) != 0 {
		t.Fatalf("SetUserLimits unknown: must not write an audit row, got %d", len(repo.auditLogs))
	}
}

// Negative caps are rejected before any lookup or write; zero is allowed (tested
// in the happy path above).
func TestSetUserLimitsNegativeIsValidation(t *testing.T) {
	ctx := context.Background()
	svc, repo := newTestService()
	user := seedUser(repo)

	if _, aerr := svc.SetUserLimits(ctx, user.ID, uuid.New(), LimitsInput{DailyTextQuota: ptr(-1)}); aerr == nil || aerr.Code != apperror.CodeValidationError {
		t.Fatalf("negative text quota: want validation_error, got %v", aerr)
	}
	if _, aerr := svc.SetUserLimits(ctx, user.ID, uuid.New(), LimitsInput{DailyImageQuota: ptr(-5)}); aerr == nil || aerr.Code != apperror.CodeValidationError {
		t.Fatalf("negative image quota: want validation_error, got %v", aerr)
	}
	if len(repo.auditLogs) != 0 {
		t.Fatalf("rejected input: must not write an audit row, got %d", len(repo.auditLogs))
	}
}
