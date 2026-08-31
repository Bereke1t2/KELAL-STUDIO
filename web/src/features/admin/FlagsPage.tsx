import { useState } from 'react';

import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Card } from '../../ui/Card';
import { PageHeader } from '../../ui/PageHeader';
import { Spinner } from '../../ui/Spinner';
import { AdminError } from './AdminError';
import { FlagRow } from './FlagRow';
import { useFlags } from './useAdminData';

/**
 * Moderation-flag review queue (PRD §6.4, §6.13).
 *
 * The snapshots are unpublished business plans (PRD §7.9) — the screen says so,
 * and `ConfidentialText` renders each one as inert plain text.
 */
export function FlagsPage() {
  const { t } = useTranslation();
  const [pendingOnly, setPendingOnly] = useState(true);
  const { data, error, loading, reload } = useFlags(pendingOnly);

  const flags = data ?? [];

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        eyebrow={t('nav.group.oversight')}
        title={t('nav.flags')}
        description={t('admin.flags.description')}
        actions={
          <div
            role="group"
            aria-label={t('admin.flags.filterLabel')}
            className="inline-flex rounded-full border border-line p-0.5"
          >
            {[
              { v: true, key: 'admin.flags.pending' as const },
              { v: false, key: 'admin.flags.all' as const },
            ].map((o) => (
              <button
                key={String(o.v)}
                type="button"
                aria-pressed={pendingOnly === o.v}
                onClick={() => setPendingOnly(o.v)}
                className={[
                  'min-h-9 rounded-full px-3 text-caption transition-colors motion-reduce:transition-none',
                  pendingOnly === o.v
                    ? 'bg-brand-subtle text-tertiary-text'
                    : 'text-ink-secondary hover:text-ink',
                ].join(' ')}
              >
                {t(o.key)}
              </button>
            ))}
          </div>
        }
      />

      <Alert tone="info">{t('admin.flags.confidential')}</Alert>

      {error ? <AdminError error={error} onRetry={reload} /> : null}
      {loading ? <Spinner label={t('state.loading')} /> : null}

      {!loading && !error && flags.length === 0 ? (
        <Card>
          <p className="text-body-sm text-ink-secondary">
            {pendingOnly ? t('admin.flags.emptyPending') : t('admin.flags.empty')}
          </p>
        </Card>
      ) : null}

      {flags.length > 0 ? (
        <ul className="flex flex-col gap-3">
          {flags.map((flag) => (
            <FlagRow key={flag.id} flag={flag} onReviewed={reload} />
          ))}
        </ul>
      ) : null}
    </div>
  );
}
