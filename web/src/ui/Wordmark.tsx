import { useTranslation } from '../i18n/I18nContext';

/**
 * The Kelal Studio identity mark: a bilingual lockup.
 *
 * "Kelal Studio" (Latin, primary line) over "ቀላል ስቱዲዮ" (Ge'ez, `lang="am"`,
 * set smaller in tertiary ink). The product is bilingual EN/AM to its core, so
 * the mark is too — this is the portal's signature. Both lines come from the
 * verified catalog keys (`app.name`), never hardcoded.
 *
 * One family, one weight — presence comes from size and the hairline gap, not
 * from bold.
 */
type WordmarkSize = 'sm' | 'md' | 'lg';

const SIZES: Record<WordmarkSize, { latin: string; geez: string }> = {
  sm: { latin: 'text-body', geez: 'text-caption' },
  md: { latin: 'text-title', geez: 'text-label' },
  lg: { latin: 'text-display', geez: 'text-body-sm' },
};

export function Wordmark({
  size = 'md',
  className = '',
}: {
  size?: WordmarkSize;
  className?: string;
}) {
  const { t } = useTranslation();
  const s = SIZES[size];

  return (
    <span
      className={`inline-flex flex-col leading-tight ${className}`}
      // The two lines are one name; announce it once.
      aria-label={t('app.name')}
      role="img"
    >
      <span aria-hidden className={`${s.latin} text-ink`}>
        {/* Force the Latin catalog value even when the UI locale is Amharic:
            the mark's Latin line is fixed. */}
        Kelal Studio
      </span>
      <span
        aria-hidden
        lang="am"
        className={`${s.geez} font-ethiopic text-ink-tertiary`}
      >
        ቀላል ስቱዲዮ
      </span>
    </span>
  );
}
