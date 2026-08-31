import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';

import { I18nProvider } from '../../../i18n/I18nContext';
import { en } from '../../../i18n/en';
import { BrandCardPreview } from './BrandCardPreview';

function renderCard(props?: Partial<Parameters<typeof BrandCardPreview>[0]>) {
  return render(
    <I18nProvider>
      <BrandCardPreview
        brandName="Abrehot"
        primaryColorHex="#402a10"
        secondaryColorHex="#c6821f"
        tone="warm"
        cardLocale="en"
        {...props}
      />
    </I18nProvider>,
  );
}

describe('BrandCardPreview', () => {
  it('renders the Amharic sample line in the Ethiopic face with lang="am"', () => {
    renderCard();
    const am = screen.getByText(/አዲስ ነገር/);
    expect(am).toHaveAttribute('lang', 'am');
    expect(am.className).toContain('font-ethiopic');
  });

  it('always shows the approximate-preview disclaimer', () => {
    renderCard();
    expect(
      screen.getByText(en['brandKit.preview.disclaimer']),
    ).toBeInTheDocument();
  });

  it('draws the safe-zone guides by default and hides them on request', () => {
    const { rerender } = renderCard();
    expect(screen.getByText(en['brandKit.preview.safeZone'])).toBeInTheDocument();
    rerender(
      <I18nProvider>
        <BrandCardPreview
          brandName="Abrehot"
          primaryColorHex="#402a10"
          secondaryColorHex="#c6821f"
          tone="warm"
          cardLocale="en"
          showSafeZones={false}
        />
      </I18nProvider>,
    );
    expect(
      screen.queryByText(en['brandKit.preview.safeZone']),
    ).not.toBeInTheDocument();
  });

  it('shows a placeholder brand name when none is given', () => {
    renderCard({ brandName: '' });
    expect(
      screen.getAllByText(en['brandKit.preview.placeholderName']).length,
    ).toBeGreaterThan(0);
  });

  it('never renders a server image (there is no GET /assets route)', () => {
    const { container } = renderCard();
    const imgs = container.querySelectorAll('img');
    imgs.forEach((img) => {
      expect(img.getAttribute('src') ?? '').not.toContain('/v1/');
    });
  });
});
