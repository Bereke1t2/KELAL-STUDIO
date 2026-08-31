import type { Locale } from './messages';

/**
 * Fill `{name}` placeholders in a message template.
 *
 * Unknown placeholders are left as-is so a copy bug is visible rather than
 * silently blank. Values are coerced to string.
 */
export function interpolate(
  template: string,
  params?: Record<string, string | number>,
): string {
  if (!params) return template;
  return template.replace(/\{(\w+)\}/g, (match, key: string) =>
    key in params ? String(params[key]) : match,
  );
}

/**
 * Locale-aware number formatting for the usage tiles.
 *
 * Latin digits are kept even for `am` — Ethiopic numerals are rarely used for
 * statistics, and switching them silently is a decision for review, not a
 * default. (Tracked as an OQ-16 formatting question.)
 */
export function formatNumber(value: number, locale: Locale): string {
  return new Intl.NumberFormat(locale === 'am' ? 'am-ET-u-nu-latn' : 'en-US').format(
    value,
  );
}

/** Locale-aware date-time formatting. Timestamps are stored UTC and only ever
 *  converted at the presentation layer (PRD §6.12). */
export function formatDateTime(iso: string, locale: Locale): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return new Intl.DateTimeFormat(locale === 'am' ? 'am-ET' : 'en-US', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(d);
}
