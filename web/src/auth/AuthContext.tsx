import {
  createContext,
  use,
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { decodeClaims, type AccessClaims } from '../api/claims';
import { refresh } from '../api/client';
import { authApi } from '../api/endpoints/auth';
import { tokens } from '../api/tokens';

type Status = 'loading' | 'authenticated' | 'anonymous';

interface AuthValue {
  status: Status;
  claims: AccessClaims | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<Status>('loading');
  const [claims, setClaims] = useState<AccessClaims | null>(null);

  const adopt = useCallback((): void => {
    const access = tokens.getAccess();
    setClaims(access ? decodeClaims(access) : null);
    setStatus(access ? 'authenticated' : 'anonymous');
  }, []);

  /*
   * Restore a session on reload. The access token is memory-only by design,
   * so after a refresh of the page there is a refresh token but no access
   * token — exchange it for a new pair before deciding the user is anonymous.
   */
  useEffect(() => {
    let cancelled = false;
    if (!tokens.getRefresh()) {
      setStatus('anonymous');
      return;
    }
    refresh()
      .catch(() => {
        // An expired or already-rotated refresh token is a normal way to
        // arrive here; `refresh` has already cleared storage.
      })
      .finally(() => {
        if (!cancelled) adopt();
      });
    return () => {
      cancelled = true;
    };
  }, [adopt]);

  const login = useCallback(
    async (email: string, password: string): Promise<void> => {
      await authApi.login(email, password);
      adopt();
    },
    [adopt],
  );

  const logout = useCallback((): void => {
    authApi.logout();
    setClaims(null);
    setStatus('anonymous');
  }, []);

  const value = useMemo(
    () => ({ status, claims, login, logout }),
    [status, claims, login, logout],
  );

  return <AuthContext value={value}>{children}</AuthContext>;
}

export function useAuth(): AuthValue {
  const ctx = use(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}
