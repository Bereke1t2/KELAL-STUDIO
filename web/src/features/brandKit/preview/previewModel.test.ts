import { describe, expect, it } from 'vitest';

import { toPreviewModel } from './previewModel';

const empty = {
  brandName: '',
  primaryColorHex: '',
  secondaryColorHex: '',
  tone: '',
};

describe('toPreviewModel', () => {
  it('falls back to design-system gold and a placeholder name when blank', () => {
    const m = toPreviewModel(empty, 'Your brand');
    expect(m.brandName).toBe('Your brand');
    expect(m.isPlaceholderName).toBe(true);
    expect(m.primary).toBe('#855312');
    expect(m.secondary).toBe('#c6821f');
  });

  it('passes valid values through and derives a legible on-colour', () => {
    const m = toPreviewModel(
      {
        brandName: '  Abrehot Coffee  ',
        primaryColorHex: '#0d0d0d',
        secondaryColorHex: 'f5d18a',
        tone: ' playful ',
      },
      'Your brand',
    );
    expect(m.brandName).toBe('Abrehot Coffee');
    expect(m.isPlaceholderName).toBe(false);
    expect(m.primary).toBe('#0d0d0d');
    expect(m.secondary).toBe('#f5d18a');
    expect(m.onPrimary).toBe('#fafafa'); // light ink on a near-black fill
    expect(m.tone).toBe('playful');
  });

  it('falls back when a colour is half-typed', () => {
    const m = toPreviewModel({ ...empty, primaryColorHex: '#12' }, 'x');
    expect(m.primary).toBe('#855312');
  });
});
