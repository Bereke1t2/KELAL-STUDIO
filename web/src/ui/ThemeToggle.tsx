import { useTranslation } from '../i18n/I18nContext';
import { useTheme, type ThemePreference } from '../theme/ThemeContext';
import type { MessageKey } from '../i18n/messages';

const OPTIONS: ReadonlyArray<{ value: ThemePreference; key: MessageKey }> = [
  { value: 'light', key: 'theme.light' },
  { value: 'dark', key: 'theme.dark' },
  { value: 'system', key: 'theme.system' },
];

/**
 * Light / Dark / System selector.
 *
 * 'System' is a real third option, not a default the other two overwrite —
 * choosing it hands control back to the OS and keeps tracking it live. A
 * native <select> so it is keyboard- and screen-reader-correct without
 * reimplementing listbox semantics.
 */
export function ThemeToggle() {
  const { preference, setPreference } = useTheme();
  const { t } = useTranslation();

  return (
    <label className="flex items-center gap-2 text-label text-ink-secondary">
      <span>{t('theme.label')}</span>
      <select
        value={preference}
        onChange={(e) => setPreference(e.target.value as ThemePreference)}
        className="min-h-11 rounded-md border border-line bg-surface px-3 text-body-sm text-ink"
      >
        {OPTIONS.map((o) => (
          <option key={o.value} value={o.value}>
            {t(o.key)}
          </option>
        ))}
      </select>
    </label>
  );
}
