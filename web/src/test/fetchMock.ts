import { vi } from 'vitest';

interface StubResponse {
  status?: number;
  body?: unknown;
}

/**
 * Replace global fetch with a matcher over `METHOD /v1/path`. Returns the mock
 * so tests can assert on calls. Unmatched routes reject loudly.
 */
export function mockFetch(routes: Record<string, StubResponse>) {
  const fn = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input.toString();
    const method = (init?.method ?? 'GET').toUpperCase();
    const key = `${method} ${url.replace(/^https?:\/\/[^/]+/, '')}`;
    const match = routes[key];
    if (!match) throw new Error(`unmocked fetch: ${key}`);
    const status = match.status ?? 200;
    return new Response(match.body === undefined ? '' : JSON.stringify(match.body), {
      status,
      headers: { 'content-type': 'application/json' },
    });
  });
  vi.stubGlobal('fetch', fn);
  return fn;
}
