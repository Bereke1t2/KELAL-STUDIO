/* oxlint-disable react-hooks/exhaustive-deps -- `deps` is a caller-provided
   dependency list, spread into the effect by contract; it cannot be an array
   literal here and that is the point of the hook. */
import { useEffect, useState } from 'react';

import { errorMessage } from '../ui/errorMessage';

export interface AsyncState<T> {
  data: T | null;
  error: string | null;
  loading: boolean;
}

/**
 * Run a fetch on mount, with cancellation and taxonomy-aware error handling.
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
    loading: true,
  });

  useEffect(() => {
    let cancelled = false;
    setState((s) => ({ ...s, loading: true }));
    fetcher()
      .then((data) => {
        if (!cancelled) setState({ data, error: null, loading: false });
      })
      .catch((err: unknown) => {
        if (cancelled) return;
        setState({ data: null, error: errorMessage(err), loading: false });
      });
    return () => {
      cancelled = true;
    };
  }, deps);

  return state;
}
