import { describe, expect, it } from 'vitest';

import { contrastRatio, isHex, normalizeHex, readableInkOn } from './hex';

describe('normalizeHex', () => {
  it('expands shorthand and lowercases', () => {
    expect(normalizeHex('#ABC')).toBe('#aabbcc');
    expect(normalizeHex('abc')).toBe('#aabbcc');
  });
  it('passes six-digit hex through with a hash', () => {
    expect(normalizeHex('1A2B3C')).toBe('#1a2b3c');
    expect(normalizeHex('#1a2b3c')).toBe('#1a2b3c');
  });
  it('rejects junk', () => {
    expect(normalizeHex('')).toBeNull();
    expect(normalizeHex('#12')).toBeNull();
    expect(normalizeHex('nope')).toBeNull();
    expect(isHex('#1a2b3c')).toBe(true);
    expect(isHex('xyz')).toBe(false);
  });
});

describe('contrastRatio', () => {
  it('is 21 for black on white', () => {
    expect(contrastRatio('#000000', '#ffffff')).toBeCloseTo(21, 0);
  });
  it('is 1 for a colour on itself', () => {
    expect(contrastRatio('#855312', '#855312')).toBeCloseTo(1, 5);
  });
  it('is null on bad input', () => {
    // note: "bad" is valid 3-digit hex (#bbaadd); use something that is not.
    expect(contrastRatio('zzz', '#fff')).toBeNull();
  });
});

describe('readableInkOn', () => {
  it('picks near-white on a dark brand colour', () => {
    expect(readableInkOn('#402a10')).toBe('#fafafa');
  });
  it('picks near-black on a pale colour', () => {
    expect(readableInkOn('#fdf6e7')).toBe('#171717');
  });
  it('falls back to near-white when unparseable', () => {
    expect(readableInkOn('???')).toBe('#fafafa');
  });
});
