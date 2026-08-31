import { useTranslation } from '../../../i18n/I18nContext';
import type { Locale } from '../../../i18n/messages';
import { BrandAvatar } from '../../../ui/BrandAvatar';
import { MockDisclaimer } from './MockDisclaimer';
import { SafeZoneOverlay } from './SafeZoneOverlay';
import { toPreviewModel, type PreviewInput } from './previewModel';

/**
 * The signature: a faithful bilingual social-card mock that updates as the
 * admin edits the Brand Kit.
 *
 * Pure and controlled — no fetching, no server image, no export control. What
 * is faithful: the font families, the fixed 1.55 line-height on both scripts,
 * the colour tokens, and the safe-zone concept. What is NOT: the exact layout,
 * real caption generation, and platform-specific crops. The disclaimer says so.
 */
export interface BrandCardPreviewProps extends PreviewInput {
  /** Which language leads the card body; the other follows beneath it. */
  cardLocale: Locale;
  showSafeZones?: boolean;
  /** An unsaved, session-only object URL for a just-picked logo. The server
   *  cannot serve a saved logo back, so this is the only time an image shows. */
  logoPreviewUrl?: string | null;
  className?: string;
}

export function BrandCardPreview({
  cardLocale,
  showSafeZones = true,
  logoPreviewUrl = null,
  className = '',
  ...input
}: BrandCardPreviewProps) {
  const { t } = useTranslation();
  const model = toPreviewModel(input, t('brandKit.preview.placeholderName'));

  const lines =
    cardLocale === 'am'
      ? ([
          { lang: 'am', font: 'font-ethiopic', key: 'brandKit.preview.sampleAm' },
          { lang: 'en', font: '', key: 'brandKit.preview.sampleEn' },
        ] as const)
      : ([
          { lang: 'en', font: '', key: 'brandKit.preview.sampleEn' },
          { lang: 'am', font: 'font-ethiopic', key: 'brandKit.preview.sampleAm' },
        ] as const);

  return (
    <figure className={`flex flex-col gap-3 ${className}`}>
      <div className="relative flex aspect-[4/5] w-full max-w-[340px] flex-col overflow-hidden rounded-lg border border-line bg-surface">
        {/* Header band — the chosen primary colour, with legible ink. */}
        <div
          style={{ backgroundColor: model.primary, color: model.onPrimary }}
          className="flex flex-col gap-1 px-5 py-4"
        >
          {logoPreviewUrl ? (
            <img
              src={logoPreviewUrl}
              alt=""
              className="mb-1 h-8 w-auto max-w-[60%] rounded-sm object-contain"
            />
          ) : (
            <BrandAvatar
              name={model.brandName}
              colorHex={model.secondary}
              sizeClass="size-8"
              className="mb-1"
            />
          )}
          <span
            className={`text-title leading-tight ${
              model.isPlaceholderName ? 'opacity-60' : ''
            }`}
          >
            {model.brandName}
          </span>
          <span className="text-caption opacity-80" lang="am">
            {/* The fixed Ge'ez wordmark line — this is a bilingual product. */}
            <span className="font-ethiopic">ቀላል ስቱዲዮ</span>
          </span>
        </div>

        {/* Body — one caption per script, both at leading-body (1.55). */}
        <div className="flex flex-1 flex-col gap-3 px-5 py-5">
          {lines.map((line, i) => (
            <p
              key={line.lang}
              lang={line.lang}
              className={[
                line.font,
                'leading-body',
                i === 0 ? 'text-body text-ink' : 'text-body-sm text-ink-secondary',
              ].join(' ')}
            >
              {t(line.key, { brand: model.brandName })}
            </p>
          ))}

          <span
            style={{ borderColor: model.secondary, color: model.secondary }}
            className="mt-auto inline-flex w-fit rounded-full border px-3 py-1 text-caption"
          >
            {t('brandKit.preview.cta')}
          </span>
        </div>

        {showSafeZones ? <SafeZoneOverlay /> : null}
      </div>

      <figcaption className="flex max-w-[340px] flex-col gap-1">
        {model.tone ? (
          <p className="text-caption text-ink-tertiary">
            {t('brandKit.preview.toneLabel', { tone: model.tone })}
          </p>
        ) : null}
        <MockDisclaimer />
      </figcaption>
    </figure>
  );
}
