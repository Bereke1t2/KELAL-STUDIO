import { useState } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { I18nProvider } from '../../i18n/I18nContext';
import { en } from '../../i18n/en';
import { ConfidentialText } from '../../ui/ConfidentialText';
import { mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/renderWithProviders';
import { FlagRow } from './FlagRow';
import { QuotaField } from './QuotaField';
import { UsagePage } from './UsagePage';

afterEach(() => vi.unstubAllGlobals());

const FEEDBACK = /success|error-|warning|danger|text-red|text-green/;

describe('UsagePage', () => {
  it('renders neutral tiles — no threshold colours', async () => {
    mockFetch({
      'GET /v1/admin/usage': {
        status: 200,
        body: {
          total_users: 12,
          total_generations: 340,
          text_generations: 200,
          image_generations: 120,
          video_generations: 20,
          total_flags: 5,
          pending_flags: 2,
        },
      },
    });
    const { container } = renderWithProviders(<UsagePage />, {
      path: '/admin/usage',
    });

    await screen.findByText('340');
    container.querySelectorAll('*').forEach((el) => {
      expect(el.className.toString()).not.toMatch(FEEDBACK);
    });
  });
});

describe('FlagRow', () => {
  const flag = {
    id: 'f1',
    user_id: 'u9',
    input_snapshot: '50% off starting Friday',
    reason: 'unverified_claim',
    reviewed_by_admin_id: null,
    reviewed_at: null,
    created_at: '2026-08-01T09:00:00Z',
  };

  it('handles a 409 as "another admin got there first" and refreshes', async () => {
    mockFetch({
      'POST /v1/admin/flags/f1/review': {
        status: 409,
        body: { error_code: 'conflict', message: 'already reviewed' },
      },
    });
    const onReviewed = vi.fn();
    render(
      <I18nProvider>
        <ul>
          <FlagRow flag={flag} onReviewed={onReviewed} />
        </ul>
      </I18nProvider>,
    );

    await userEvent.click(
      screen.getByRole('button', { name: en['admin.flags.markReviewed'] }),
    );
    expect(
      await screen.findByText(en['admin.flags.alreadyReviewed']),
    ).toBeInTheDocument();
    expect(onReviewed).toHaveBeenCalled();
  });
});

describe('QuotaField', () => {
  it('maps the three modes to null / 0 / a positive number', async () => {
    const onChange = vi.fn();

    function Harness() {
      const [v, setV] = useState<number | null>(null);
      return (
        <I18nProvider>
          <QuotaField
            label="Text"
            value={v}
            onChange={(next) => {
              onChange(next);
              setV(next);
            }}
          />
        </I18nProvider>
      );
    }
    render(<Harness />);

    await userEvent.click(screen.getByLabelText(en['admin.limits.block']));
    expect(onChange).toHaveBeenLastCalledWith(0);

    await userEvent.click(screen.getByLabelText(en['admin.limits.custom']));
    expect(onChange.mock.lastCall?.[0]).toBeGreaterThan(0);

    await userEvent.click(screen.getByLabelText(en['admin.limits.default']));
    expect(onChange).toHaveBeenLastCalledWith(null);
  });
});

describe('ConfidentialText', () => {
  it('renders untrusted text inert — no injected markup', () => {
    const raw = '<script>x</script> and [a](http://evil.example)';
    const { container } = render(<ConfidentialText text={raw} />);
    expect(container.textContent).toBe(raw);
    expect(container.querySelector('script')).toBeNull();
    expect(container.querySelector('a')).toBeNull();
  });
});
