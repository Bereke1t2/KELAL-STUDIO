import { useTranslation } from '../i18n/I18nContext';
import type { MessageKey } from '../i18n/messages';
import { Card } from '../ui/Card';
import { PageHeader } from '../ui/PageHeader';

/**
 * Stand-in for a screen that lands in a later branch of the rebuild stack.
 * Replaced route-by-route by `feat/web-brand-kit-and-preview` and
 * `feat/web-admin`.
 */
export function PlaceholderPage({
  eyebrowKey,
  titleKey,
}: {
  eyebrowKey: MessageKey;
  titleKey: MessageKey;
}) {
  const { t } = useTranslation();
  return (
    <div className="flex flex-col gap-8">
      <PageHeader eyebrow={t(eyebrowKey)} title={t(titleKey)} />
      <Card>
        <p className="text-body text-ink-secondary">{t('placeholder.body')}</p>
      </Card>
    </div>
  );
}
