import { useCallback } from 'react';

import { adminApi } from '../../api/endpoints/admin';
import { useAsync } from '../../lib/useAsync';
import { Alert } from '../../ui/Alert';
import { NotBuilt } from './NotBuilt';

/**
 * Usage & telemetry (PRD §6.13, acceptance criterion 8).
 *
 * These are single magnitudes, so they are stat tiles — not charts. There is
 * no series to distinguish and nothing to plot over time yet.
 *
 * Tiles are deliberately NOT threshold-coloured. PRD §2.3 names the metrics to
 * collect but sets no numeric target for any of them, and "activated user" is
 * undefined — so painting an error rate red would invent a pass/fail bar the
 * product has not set. Once targets exist (§14), add status colour with an
 * icon and label, never colour alone.
 */
function Tile({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-line bg-surface p-4">
      <div className="text-sm text-ink-tertiary">{label}</div>
      {/* tabular-nums so figures do not jitter as they refresh */}
      <div className="mt-1 text-2xl tabular-nums text-ink">{value}</div>
    </div>
  );
}

const NONE = '—';

const fmtInt = (n: number | undefined): string =>
  n === undefined ? NONE : n.toLocaleString();

const fmtMs = (n: number | undefined): string =>
  n === undefined ? NONE : `${n.toLocaleString()} ms`;

const fmtRate = (n: number | undefined): string =>
  n === undefined ? NONE : `${(n * 100).toFixed(1)}%`;

export function UsagePage() {
  const fetcher = useCallback(() => adminApi.usage(), []);
  const { data, error, notBuilt, loading } = useAsync(fetcher, [fetcher]);

  return (
    <section className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <h1 className="text-2xl">Usage</h1>
        <p className="text-sm text-ink-secondary">
          Live generation counts, latency, and queue health.
        </p>
      </div>

      {loading ? <p className="text-ink-tertiary">Loading usage…</p> : null}
      {notBuilt ? <NotBuilt slice="Admin usage" /> : null}
      {error ? <Alert tone="error">{error}</Alert> : null}

      {data ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Tile label="Generations" value={fmtInt(data.generations_total)} />
          <Tile label="Error rate" value={fmtRate(data.error_rate)} />
          <Tile label="Latency P50" value={fmtMs(data.latency_p50_ms)} />
          <Tile label="Latency P95" value={fmtMs(data.latency_p95_ms)} />
          <Tile label="Queue depth" value={fmtInt(data.queue_depth)} />
        </div>
      ) : null}
    </section>
  );
}
