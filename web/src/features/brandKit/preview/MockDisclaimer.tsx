import { useTranslation } from '../../../i18n/I18nContext';

/**
 * Permanent, non-dismissible note under the preview card. The card is a
 * CSS mock — it is NOT what the device renderer produces at export time — and
 * it must never read as something that can produce a real asset (hence: no
 * export/download control anywhere near it).
 */
export function MockDisclaimer() {
  const { t } = useTranslation();
  return (
    <p className="text-caption text-ink-tertiary">
      {t('brandKit.preview.disclaimer')}
    </p>
  );
}
