import { useEffect, useState } from 'react';

import { ApiError } from '../api/errors';
import { errorMessage } from '../ui/errorMessage';

export interface AsyncState<T> {
  data: T | null;
  error: string | null;
  /** True when the route exists but is not implemented server-side (501). */
  notBuilt: boolean;
  loading: boolean;
}

/**
 * Run a fetch on mount, with cancellation and taxonomy-aware error handling.
 *
 * `notBuilt` is split out from `error` deliberately: every /admin/* route
 * currently returns not_implemented, and that is a normal, expected state of
 * this codebase rather than a failure the operator should see styled as one.
 *
 * `deps` is spread into the effect's dependency list, so callers must pass a
 * stable array — the same discipline any useEffect dependency needs.
 */
export function useAsync<T>(
  fetcher: () => Promise<T>,
  deps: readonly unknown[] = [],
): AsyncState<T> {
  const [state, setState] = useState<AsyncState<T>>({
    data: null,
    error: null,
    notBuilt: false,
    loading: true,
  });

  useEffect(() => {
    let cancelled = false;
    setState((s) => ({ ...s, loading: true }));
    fetcher()
      .then((data) => {
        if (!cancelled) {
          setState({ data, error: null, notBuilt: false, loading: false });
        }
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        const notBuilt = err instanceof ApiError && err.isNotImplemented;
        setState({
          data: null,
          error: notBuilt ? null : errorMessage(err),
          notBuilt,
          loading: false,
        });
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return state;
}
