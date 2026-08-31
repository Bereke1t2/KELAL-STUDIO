import { useCallback, useState } from 'react';

import { adminApi } from '../../api/endpoints/admin';
import type { ModerationFlag } from '../../api/types';
import { useAsync } from '../../lib/useAsync';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { NotBuilt } from './NotBuilt';

/**
 * Flagged-prompt review queue (PRD §6.4, §6.13, acceptance criterion 15).
 *
 * The rows here are user prompts, which the PRD treats as competitively
 * sensitive — "50% off starting Friday" is an unannounced business plan until
 * published (§7.9, OQ-13). So prompt text is rendered as plain text only,
 * never as markup, and never linked out to a third-party service. React
 * escapes by default; do not introduce dangerouslySetInnerHTML here.
 *
 * Reviewing is an administrative action and MUST be audit-logged server-side
 * (§6.13) — an audit log administrators can silently modify is not one. This
 * screen relies on the backend for that; it does not write the trail itself.
 */
function Row({
  flag,
  onReviewed,
}: {
  flag: ModerationFlag;
  onReviewed: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function review(decision: 'upheld' | 'overturned'): Promise<void> {
    if (busy || !flag.id) return;
    setBusy(true);
    setError(null);
    try {
      await adminApi.reviewFlag(flag.id, decision, '');
      onReviewed();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <tr className="border-t border-line align-top">
      <td className="p-3 text-sm text-ink-tertiary whitespace-nowrap">
        {flag.created_at ? new Date(flag.created_at).toLocaleString() : '—'}
      </td>
      <td className="max-w-md p-3 text-sm text-ink">
        {flag.input_text ?? '—'}
        {error ? (
          <p className="mt-1 text-error-text">{error}</p>
        ) : null}
      </td>
      <td className="p-3 text-sm text-ink-secondary">{flag.input_lang ?? '—'}</td>
      <td className="p-3 text-sm text-ink-secondary">{flag.reason ?? '—'}</td>
      <td className="p-3">
        {flag.reviewed ? (
          <span className="text-sm text-ink-tertiary">Reviewed</span>
        ) : (
          <div className="flex gap-2">
            <Button variant="secondary" disabled={busy} onClick={() => review('upheld')}>
              Uphold
            </Button>
            <Button variant="tertiary" disabled={busy} onClick={() => review('overturned')}>
              Overturn
            </Button>
          </div>
        )}
      </td>
    </tr>
  );
}

export function FlagsPage() {
  const [reloadKey, setReloadKey] = useState(0);
  const fetcher = useCallback(() => adminApi.listFlags(), []);
  const { data, error, notBuilt, loading } = useAsync(fetcher, [fetcher, reloadKey]);
  const reload = useCallback(() => setReloadKey((k) => k + 1), []);

  return (
    <section className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <h1 className="text-2xl">Flagged prompts</h1>
        <p className="text-sm text-ink-secondary">
          Prompts the safety filter refused. Contains unpublished customer
          business information — treat as confidential.
        </p>
      </div>

      {loading ? <p className="text-ink-tertiary">Loading flags…</p> : null}
      {notBuilt ? <NotBuilt slice="Flagged-prompt review" /> : null}
      {error ? <Alert tone="error">{error}</Alert> : null}

      {data && data.length === 0 ? (
        <Alert tone="info">No flagged prompts.</Alert>
      ) : null}

      {data && data.length > 0 ? (
        // A wide table must scroll inside its own container rather than making
        // the page scroll sideways.
        <div className="overflow-x-auto rounded-lg border border-line bg-surface">
          <table className="w-full border-collapse text-left">
            <thead>
              <tr className="text-sm text-ink-tertiary">
                <th className="p-3 font-normal">Flagged</th>
                <th className="p-3 font-normal">Prompt</th>
                <th className="p-3 font-normal">Lang</th>
                <th className="p-3 font-normal">Reason</th>
                <th className="p-3 font-normal">Review</th>
              </tr>
            </thead>
            <tbody>
              {data.map((f) => (
                <Row key={f.id ?? f.created_at} flag={f} onReviewed={reload} />
              ))}
            </tbody>
          </table>
        </div>
      ) : null}
    </section>
  );
}
