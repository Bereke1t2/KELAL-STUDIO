import { useTranslation } from '../../i18n/I18nContext';
import type { MessageKey } from '../../i18n/messages';
import type { AdminUsage } from '../../api/types';
import { Card } from '../../ui/Card';
import { PageHeader } from '../../ui/PageHeader';
import { Spinner } from '../../ui/Spinner';
import { AdminError } from './AdminError';
import { useAdminUsage } from './useAdminData';

/**
 * Whole-population usage counts (PRD §6.13).
 *
 * Every tile looks the same — no threshold colours, no "good/bad". The PRD
 * (§2.3) sets no numeric target for any metric yet, so a coloured tile would be
 * asserting a judgement the product has not made. When targets exist, add
 * status with an icon + label, never colour alone.
 */
const TILES: ReadonlyArray<{ key: keyof AdminUsage; label: MessageKey }> = [
  { key: 'total_users', label: 'admin.usage.totalUsers' },
  { key: 'total_generations', label: 'admin.usage.totalGenerations' },
  { key: 'text_generations', label: 'admin.usage.textGenerations' },
  { key: 'image_generations', label: 'admin.usage.imageGenerations' },
  { key: 'video_generations', label: 'admin.usage.videoGenerations' },
  { key: 'total_flags', label: 'admin.usage.totalFlags' },
  { key: 'pending_flags', label: 'admin.usage.pendingFlags' },
];

export function UsagePage() {
  const { t, formatNumber } = useTranslation();
  const { data, error, loading, reload } = useAdminUsage();

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        eyebrow={t('nav.group.oversight')}
        title={t('nav.usage')}
        description={t('admin.usage.description')}
      />

      {error ? <AdminError error={error} onRetry={reload} /> : null}
      {loading ? <Spinner label={t('state.loading')} /> : null}

      {data ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {TILES.map((tile) => (
            <Card key={tile.key} pad="md" className="flex flex-col gap-1">
              <span className="text-caption uppercase tracking-[0.12em] text-ink-tertiary">
                {t(tile.label)}
              </span>
              <span className="text-display text-ink">
                {formatNumber(data[tile.key] ?? 0)}
              </span>
            </Card>
          ))}
        </div>
      ) : null}
    </div>
  );
}
