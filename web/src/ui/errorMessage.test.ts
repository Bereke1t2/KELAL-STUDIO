import { describe, expect, it } from 'vitest';

import { ApiError } from '../api/errors';
import { en } from '../i18n/en';
import type { MessageKey } from '../i18n/messages';
import { errorMessage } from './errorMessage';

// A minimal translator: return the English template with `{k}` filled in.
const t = (key: MessageKey, params?: Record<string, string | number>): string => {
  const template: string = en[key];
  return params
    ? template.replace(/\{(\w+)\}/g, (m, k: string) => String(params[k] ?? m))
    : template;
};

describe('errorMessage', () => {
  it('falls back to the network message for a non-ApiError', () => {
    expect(errorMessage(new Error('fetch failed'), t)).toBe(en['error.network']);
  });

  it('prefers the backend message for an unrecognised code', () => {
    const err = new ApiError(418, {
      error_code: 'teapot',
      message: 'I am a teapot.',
    });
    expect(errorMessage(err, t)).toBe('I am a teapot.');
  });

  it('phrases a known infra code without leaking the status', () => {
    const err = new ApiError(401, { error_code: 'unauthorized', message: 'nope' });
    expect(errorMessage(err, t)).toBe(en['error.session']);
  });

  it('includes the reset time for a quota error', () => {
    const err = new ApiError(429, {
      error_code: 'quota_exceeded',
      message: 'x',
      resets_at: '2026-01-01T00:00:00Z',
    });
    expect(errorMessage(err, t)).toContain('2026');
  });
});
