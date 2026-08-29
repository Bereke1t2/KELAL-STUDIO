import {
  createContext,
  use,
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { en } from './en';
import am from './am';
import { formatDateTime, formatNumber, interpolate } from './format';
import { LOCALES, type Locale, type MessageKey } from './messages';

/**
 * Owns the active locale and the `lang` attribute on <html>.
 *
 * A ~2 kB catalog per locale, both statically imported — no code-split, so a
 * language switch is instant and there is no flash. `index.html` sets
 * `<html lang>` before first paint from the same `kelal.lang` key; this
 * controller takes it over from then on. Ethiopic is LTR, so `dir` is left
 * untouched.
 *
 * Amharic strings are placeholders pending native-speaker review (see am.ts).
 */
const STORAGE_KEY = 'kelal.lang';

const CATALOGS: Record<Locale, Record<MessageKey, string>> = { en, am };

function readStored(): Locale {
  try {
    const v = localStorage.getItem(STORAGE_KEY);
    if (v === 'en' || v === 'am') return v;
  } catch {
    // Blocked storage — fall through to the navigator guess.
  }
  return navigator.language.slice(0, 2) === 'am' ? 'am' : 'en';
}

interface I18nValue {
  locale: Locale;
  locales: readonly Locale[];
  setLocale: (next: Locale) => void;
  /** Translate a key, with optional `{placeholder}` params. */
  t: (key: MessageKey, params?: Record<string, string | number>) => string;
  formatNumber: (value: number) => string;
  formatDateTime: (iso: string) => string;
}

const I18nContext = createContext<I18nValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(readStored);

  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);

  const setLocale = useCallback((next: Locale): void => {
    setLocaleState(next);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // Won't persist across reloads; not worth failing on.
    }
  }, []);

  const t = useCallback(
    (key: MessageKey, params?: Record<string, string | number>): string => {
      // `?? en[key] ?? key`: noUncheckedIndexedAccess types the lookup as
      // possibly undefined, and a missing Amharic value should fall back to
      // English rather than render blank.
      const template = CATALOGS[locale][key] ?? en[key] ?? key;
      return interpolate(template, params);
    },
    [locale],
  );

  const value = useMemo<I18nValue>(
    () => ({
      locale,
      locales: LOCALES,
      setLocale,
      t,
      formatNumber: (v: number) => formatNumber(v, locale),
      formatDateTime: (iso: string) => formatDateTime(iso, locale),
    }),
    [locale, setLocale, t],
  );

  return <I18nContext value={value}>{children}</I18nContext>;
}

export function useTranslation(): I18nValue {
  const ctx = use(I18nContext);
  if (!ctx) throw new Error('useTranslation must be used inside <I18nProvider>');
  return ctx;
}
