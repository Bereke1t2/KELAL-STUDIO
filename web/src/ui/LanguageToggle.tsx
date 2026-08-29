import { useTranslation } from '../i18n/I18nContext';
import type { Locale } from '../i18n/messages';

/**
 * Two-option segmented control for the interface language.
 *
 * The Amharic option is labelled in Amharic (አማርኛ) and set in the Ethiopic
 * face, so the choice reads in its own script. Available on every screen (shell
 * and auth) from day one.
 */
const OPTIONS: ReadonlyArray<{ value: Locale; key: 'lang.en' | 'lang.am' }> = [
  { value: 'en', key: 'lang.en' },
  { value: 'am', key: 'lang.am' },
];

export function LanguageToggle() {
  const { locale, setLocale, t } = useTranslation();

  return (
    <div
      role="group"
      aria-label={t('lang.label')}
      className="inline-flex items-center rounded-full border border-line p-0.5"
    >
      {OPTIONS.map((o) => {
        const active = o.value === locale;
        return (
          <button
            key={o.value}
            type="button"
            aria-pressed={active}
            lang={o.value}
            onClick={() => setLocale(o.value)}
            className={[
              'min-h-11 rounded-full px-3.5 text-label transition-colors',
              'motion-reduce:transition-none',
              o.value === 'am' ? 'font-ethiopic' : '',
              active
                ? 'bg-brand-subtle text-tertiary-text'
                : 'text-ink-secondary hover:text-ink',
            ].join(' ')}
          >
            {t(o.key)}
          </button>
        );
      })}
    </div>
  );
}
