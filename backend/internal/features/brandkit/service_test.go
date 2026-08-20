package brandkit

import (
	"context"
	"io"
	"log/slog"
	"testing"

	"github.com/google/uuid"

	"github.com/Bereke1t2/KELAL-STUDIO/backend/internal/platform/apperror"
)

// These tests run entirely on the in-memory repository — no Postgres, no
// network. They mirror the auth feature's service_test.go: construct the service
// with the mock adapter, exercise use cases, and assert on the returned
// (result, *apperror.Error).

func discardLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func newTestService() *Service {
	return NewService(NewMockRepository(), discardLogger())
}

func TestUpsertCreatesThenGet(t *testing.T) {
	ctx := context.Background()
	svc := newTestService()
	owner := uuid.New()
	id := uuid.New()

	created, aerr := svc.Upsert(ctx, id, owner, Input{
		BrandName:       "Kelal Studio",
		PrimaryColorHex: "#112233",
	})
	if aerr != nil {
		t.Fatalf("Upsert create: unexpected error: %v", aerr)
	}
	if created.ID != id || created.UserID != owner {
		t.Fatalf("Upsert create: want id=%s owner=%s, got id=%s owner=%s", id, owner, created.ID, created.UserID)
	}
	if created.BrandName != "Kelal Studio" || created.PrimaryColorHex != "#112233" {
		t.Fatalf("Upsert create: fields not persisted: %+v", created)
	}
	if created.UpdatedAt.IsZero() {
		t.Fatalf("Upsert create: expected updated_at to be set")
	}

	got, aerr := svc.Get(ctx, id, owner)
	if aerr != nil {
		t.Fatalf("Get: unexpected error: %v", aerr)
	}
	if got.ID != id || got.BrandName != "Kelal Studio" {
		t.Fatalf("Get: want the created kit, got %+v", got)
	}
}

func TestGetUnknownIsNotFound(t *testing.T) {
	ctx := context.Background()
	svc := newTestService()

	_, aerr := svc.Get(ctx, uuid.New(), uuid.New())
	if aerr == nil || aerr.Code != apperror.CodeNotFound {
		t.Fatalf("Get unknown: want not_found, got %v", aerr)
	}
}

// A kit is owner-scoped: another user can neither read it nor overwrite it, and
// both failures are an indistinguishable 404 (never 403 — see Service.Get).
func TestOwnershipIsolation(t *testing.T) {
	ctx := context.Background()
	svc := newTestService()
	alice, bob := uuid.New(), uuid.New()
	id := uuid.New()

	if _, aerr := svc.Upsert(ctx, id, alice, Input{BrandName: "Alice Co"}); aerr != nil {
		t.Fatalf("setup Upsert: %v", aerr)
	}

	if _, aerr := svc.Get(ctx, id, bob); aerr == nil || aerr.Code != apperror.CodeNotFound {
		t.Fatalf("Get other's kit: want not_found, got %v", aerr)
	}
	if _, aerr := svc.Upsert(ctx, id, bob, Input{BrandName: "Bob hijack"}); aerr == nil || aerr.Code != apperror.CodeNotFound {
		t.Fatalf("Upsert over other's kit: want not_found, got %v", aerr)
	}

	// Alice's kit is untouched by Bob's attempts.
	got, aerr := svc.Get(ctx, id, alice)
	if aerr != nil {
		t.Fatalf("Get after hijack attempt: %v", aerr)
	}
	if got.BrandName != "Alice Co" {
		t.Fatalf("Get after hijack attempt: want unchanged 'Alice Co', got %q", got.BrandName)
	}
}

// A second PUT updates in place: same id, owner and created_at preserved,
// updated_at not moving backwards, and the new field values applied.
func TestUpsertUpdatesInPlace(t *testing.T) {
	ctx := context.Background()
	svc := newTestService()
	owner := uuid.New()
	id := uuid.New()

	first, aerr := svc.Upsert(ctx, id, owner, Input{BrandName: "one"})
	if aerr != nil {
		t.Fatalf("first Upsert: %v", aerr)
	}

	logo := uuid.New()
	second, aerr := svc.Upsert(ctx, id, owner, Input{BrandName: "two", LogoAssetID: &logo})
	if aerr != nil {
		t.Fatalf("second Upsert: %v", aerr)
	}

	if second.ID != id || second.UserID != owner {
		t.Fatalf("update changed identity: id=%s owner=%s", second.ID, second.UserID)
	}
	if !second.CreatedAt.Equal(first.CreatedAt) {
		t.Fatalf("update should preserve created_at: %v vs %v", second.CreatedAt, first.CreatedAt)
	}
	if second.UpdatedAt.Before(first.UpdatedAt) {
		t.Fatalf("update should not move updated_at backwards: %v < %v", second.UpdatedAt, first.UpdatedAt)
	}
	if second.BrandName != "two" || second.LogoAssetID == nil || *second.LogoAssetID != logo {
		t.Fatalf("update did not apply new fields: %+v", second)
	}
}
