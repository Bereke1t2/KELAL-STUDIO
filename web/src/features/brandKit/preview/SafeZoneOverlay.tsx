import { useTranslation } from '../../../i18n/I18nContext';

/**
 * Dashed inset guides over the preview card. Communicates the mobile
 * safe-zone concept — "keep text and logo inside the guides so nothing is
 * clipped when a platform crops the post" — without claiming pixel parity
 * with the device renderer.
 */
export function SafeZoneOverlay() {
  const { t } = useTranslation();
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0">
      {/* Outer margin box (~8%). */}
      <div className="absolute inset-[8%] rounded-sm border border-dashed border-line-strong opacity-70" />
      {/* Title-safe box (~18%). */}
      <div className="absolute inset-x-[18%] inset-y-[22%] rounded-sm border border-dashed border-line-strong opacity-40" />
      <span className="absolute left-[8%] top-[3%] text-[10px] uppercase tracking-[0.12em] text-ink-tertiary">
        {t('brandKit.preview.safeZone')}
      </span>
    </div>
  );
}
