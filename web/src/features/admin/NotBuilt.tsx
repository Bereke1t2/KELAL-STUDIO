import { Alert } from '../../ui/Alert';

/**
 * Shown when a route returns not_implemented (501).
 *
 * Every /admin/* endpoint is a stub today (backend/docs/FEATURE_OWNERSHIP.md),
 * so this is a routine state, not a crash. It is styled as information rather
 * than an error, and names the slice so an operator reading it knows this is
 * unbuilt work rather than an outage they should report.
 */
export function NotBuilt({ slice }: { slice: string }) {
  return (
    <Alert tone="info">
      {slice} is not built yet — the endpoint is wired but returns
      “not implemented”. Tracked in backend/docs/FEATURE_OWNERSHIP.md.
    </Alert>
  );
}
