import { en } from './en';

/** Every valid message key. Derived from the English catalog. */
export type MessageKey = keyof typeof en;

/** A complete catalog for one locale — same keys as English, no more, no less. */
export type Messages = Record<MessageKey, string>;

export type Locale = 'en' | 'am';

export const LOCALES: readonly Locale[] = ['en', 'am'];

/**
 * Keys whose Amharic value is verified (from Figma / the mobile app), so the
 * drift test does not require them to differ from English by review. Everything
 * else in `am.ts` is a best-effort placeholder pending native-speaker review.
 */
export const VERIFIED_AM_KEYS: readonly MessageKey[] = ['app.name', 'app.tagline'];
