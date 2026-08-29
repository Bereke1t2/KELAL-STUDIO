import { useDeferredValue, useState } from 'react';

import { useAuth } from '../../auth/AuthContext';
import { useTranslation } from '../../i18n/I18nContext';
import type { Locale } from '../../i18n/messages';
import { useObjectUrl } from '../../lib/useObjectUrl';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { Card } from '../../ui/Card';
import { errorMessage } from '../../ui/errorMessage';
import { PageHeader } from '../../ui/PageHeader';
import { Spinner } from '../../ui/Spinner';
import { BrandKitForm } from './BrandKitForm';
import { useBrandKit } from './useBrandKit';
import { BrandCardPreview } from './preview/BrandCardPreview';

/**
 * Brand Kit configuration + the live preview.
 *
 * The kit is addressed at the signed-in user's `sub` — see the flag in
 * `useBrandKit`. Saved values are pulled into mobile generation on the user's
 * next session, which the page says out loud.
 */
export function BrandKitPage() {
  const { claims } = useAuth();
  const { t } = useTranslation();
  const kitId = claims?.sub ?? '';
  const kit = useBrandKit(kitId);

  const [cardLocale, setCardLocale] = useState<Locale>('en');
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const logoUrl = useObjectUrl(logoFile);

  const preview = useDeferredValue({
    brandName: kit.draft.brand_name ?? '',
    primaryColorHex: kit.draft.primary_color_hex ?? '',
    secondaryColorHex: kit.draft.secondary_color_hex ?? '',
    tone: kit.draft.tone_of_voice ?? '',
  });

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        eyebrow={t('nav.group.brand')}
        title={t('nav.brandKit')}
        description={t('brandKit.description')}
      />

      {kit.loadError ? (
        <Alert tone="error">{errorMessage(kit.loadError, t)}</Alert>
      ) : null}

      {kit.loading ? (
        <Spinner label={t('state.loading')} />
      ) : (
        <div className="flex flex-col gap-10 lg:flex-row lg:items-start">
          <div className="flex min-w-0 flex-1 flex-col gap-6">
            <BrandKitForm
              draft={kit.draft}
              update={kit.update}
              onLogoFile={setLogoFile}
            />

            {kit.saveError ? (
              <Alert tone="error">{errorMessage(kit.saveError, t)}</Alert>
            ) : null}
            {kit.savedAt && !kit.dirty ? (
              <Alert tone="success">{t('brandKit.saved')}</Alert>
            ) : null}

            <div className="flex items-center gap-4 border-t border-line-subtle pt-4">
              <Button
                onClick={() => void kit.save()}
                disabled={!kit.dirty || kit.saving}
              >
                {kit.saving ? t('action.saving') : t('action.save')}
              </Button>
              {kit.dirty ? (
                <span className="text-caption text-ink-tertiary">
                  {t('brandKit.unsaved')}
                </span>
              ) : null}
            </div>
          </div>

          <div className="lg:sticky lg:top-12 lg:w-[360px] lg:shrink-0 lg:self-start">
            <div className="flex flex-col gap-3">
              <div className="flex items-center justify-between">
                <span className="text-caption uppercase tracking-[0.12em] text-ink-tertiary">
                  {t('brandKit.preview.title')}
                </span>
                <LocaleToggle value={cardLocale} onChange={setCardLocale} />
              </div>
              <Card pad="sm">
                <BrandCardPreview
                  {...preview}
                  cardLocale={cardLocale}
                  logoPreviewUrl={logoUrl}
                />
              </Card>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function LocaleToggle({
  value,
  onChange,
}: {
  value: Locale;
  onChange: (l: Locale) => void;
}) {
  const { t } = useTranslation();
  return (
    <div
      role="group"
      aria-label={t('brandKit.preview.localeLabel')}
      className="inline-flex rounded-full border border-line p-0.5"
    >
      {(['en', 'am'] as const).map((l) => (
        <button
          key={l}
          type="button"
          aria-pressed={l === value}
          lang={l}
          onClick={() => onChange(l)}
          className={[
            'min-h-9 rounded-full px-3 text-caption transition-colors motion-reduce:transition-none',
            l === 'am' ? 'font-ethiopic' : '',
            l === value
              ? 'bg-brand-subtle text-tertiary-text'
              : 'text-ink-secondary hover:text-ink',
          ].join(' ')}
        >
          {t(l === 'en' ? 'lang.en' : 'lang.am')}
        </button>
      ))}
    </div>
  );
}
