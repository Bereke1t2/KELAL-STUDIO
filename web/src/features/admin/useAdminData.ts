import { useCallback, useEffect, useRef, useState } from 'react';

import { adminApi } from '../../api/endpoints/admin';
import type { AdminUsage, ModerationFlag } from '../../api/types';

interface Loaded<T> {
  data: T | null;
  error: unknown;
  loading: boolean;
  reload: () => void;
}

/** GET /admin/usage, with a manual reload. */
export function useAdminUsage(): Loaded<AdminUsage> {
  return useLoader(useCallback(() => adminApi.usage(), []));
}

/** GET /admin/flags, re-fetching when `pendingOnly` changes or after a review. */
export function useFlags(pendingOnly: boolean): Loaded<ModerationFlag[]> {
  const fetcher = useCallback(
    () => adminApi.listFlags(pendingOnly ? 'pending' : undefined),
    [pendingOnly],
  );
  return useLoader(fetcher);
}

function useLoader<T>(fetcher: () => Promise<T>): Loaded<T> {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);
  const [tick, setTick] = useState(0);
  const reqId = useRef(0);

  useEffect(() => {
    const mine = ++reqId.current;
    setLoading(true);
    setError(null);
    fetcher()
      .then((d) => {
        if (mine === reqId.current) setData(d);
      })
      .catch((e: unknown) => {
        if (mine === reqId.current) setError(e);
      })
      .finally(() => {
        if (mine === reqId.current) setLoading(false);
      });
  }, [fetcher, tick]);

  const reload = useCallback(() => setTick((n) => n + 1), []);
  return { data, error, loading, reload };
}
