import { describe, expect, it } from 'vitest';

import { ApiError } from '../api/errors';
import { errorMessage } from './errorMessage';

describe('errorMessage', () => {
  it('falls back to a plain-language network message for a non-ApiError', () => {
    expect(errorMessage(new Error('fetch failed'))).toMatch(/reach the server/i);
  });

  it('prefers the backend message for an unrecognised code', () => {
    const err = new ApiError(418, {
      error_code: 'teapot',
      message: 'I am a teapot.',
    });
    expect(errorMessage(err)).toBe('I am a teapot.');
  });

  it('phrases a known infra code without leaking the status', () => {
    const err = new ApiError(401, {
      error_code: 'unauthorized',
      message: 'nope',
    });
    expect(errorMessage(err)).toMatch(/sign in again/i);
  });
});
