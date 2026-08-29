import { describe, expect, it } from 'vitest';

import { en } from '../en';
import am from '../am';
import { VERIFIED_AM_KEYS, type MessageKey } from '../messages';

const enKeys = Object.keys(en) as MessageKey[];
const amKeys = Object.keys(am) as MessageKey[];

describe('i18n catalog parity', () => {
  it('am has exactly the same keys as en', () => {
    expect(new Set(amKeys)).toEqual(new Set(enKeys));
  });

  it('no am value is empty or whitespace', () => {
    const blank = enKeys.filter((k) => !am[k] || !am[k].trim());
    expect(blank).toEqual([]);
  });

  it('every non-verified am value differs from en (i.e. was actually translated)', () => {
    const allowlist = new Set<MessageKey>([
      ...VERIFIED_AM_KEYS,
      // Language names are intentionally the same in both catalogs.
      'lang.en',
      'lang.am',
    ]);
    const untranslated = enKeys.filter(
      (k) => !allowlist.has(k) && am[k] === en[k],
    );
    expect(untranslated).toEqual([]);
  });
});
