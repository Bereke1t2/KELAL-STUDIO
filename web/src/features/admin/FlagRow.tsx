import { useState } from 'react';

import { adminApi } from '../../api/endpoints/admin';
import { ApiError } from '../../api/errors';
import type { ModerationFlag } from '../../api/types';
import { useTranslation } from '../../i18n/I18nContext';
import { Button } from '../../ui/Button';
import { Card } from '../../ui/Card';
import { ConfidentialText } from '../../ui/ConfidentialText';
import { CopyButton } from '../../ui/CopyButton';
import { errorMessage } from '../../ui/errorMessage';

/**
 * One moderation-flag entry. Review is a single bodyless action; a second
 * review (another admin got there first) is a 409, surfaced calmly and
 * followed by a refresh.
 */
export function FlagRow({
  flag,
  onReviewed,
}: {
  flag: ModerationFlag;
  onReviewed: () => void;
}) {
  const { t, formatDateTime } = useTranslation();
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);

  const reviewed = Boolean(flag.reviewed_at);

  async function review(): Promise<void> {
    if (busy || !flag.id) return;
    setBusy(true);
    setNote(null);
    try {
      await adminApi.reviewFlag(flag.id);
      onReviewed();
    } catch (err) {
      if (err instanceof ApiError && err.status === 409) {
        setNote(t('admin.flags.alreadyReviewed'));
        onReviewed();
      } else {
        setNote(errorMessage(err, t));
        setBusy(false);
      }
    }
  }

  return (
    <Card as="li" pad="md" className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-caption text-ink-tertiary">
        <span>{flag.created_at ? formatDateTime(flag.created_at) : '—'}</span>
        <span className="flex items-center gap-1">
          <span className="font-mono">{flag.user_id ?? '—'}</span>
          {flag.user_id ? <CopyButton value={flag.user_id} /> : null}
        </span>
      </div>

      {flag.reason ? (
        <p className="text-body-sm text-ink-secondary">{flag.reason}</p>
      ) : null}

      <ConfidentialText text={flag.input_snapshot ?? ''} />

      <div className="flex items-center gap-3">
        {reviewed ? (
          <span className="text-caption text-ink-tertiary">
            {t('admin.flags.reviewedBy', {
              id: flag.reviewed_by_admin_id ?? '—',
              at: flag.reviewed_at ? formatDateTime(flag.reviewed_at) : '—',
            })}
          </span>
        ) : (
          <Button variant="secondary" onClick={review} disabled={busy}>
            {t('admin.flags.markReviewed')}
          </Button>
        )}
        {note ? (
          <span className="text-caption text-ink-secondary" role="status">
            {note}
          </span>
        ) : null}
      </div>
    </Card>
  );
}
