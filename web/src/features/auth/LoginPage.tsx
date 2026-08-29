import { useState, type FormEvent } from 'react';

import { useAuth } from '../../auth/AuthContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Field } from '../../ui/Field';

/**
 * Portal sign-in.
 *
 * Temporary shape for the teardown branch: email + password only. The
 * redesigned sign-in and the rest of the front door (register, verify email,
 * password reset) land in `feat/web-self-serve-auth`, stacked on top of this.
 */
export function LoginPage() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await login(email, password);
    } catch (err) {
      // The backend returns one generic message for a wrong password AND an
      // unknown email, by design (PRD §6.1) — do not try to be more specific.
      setError(errorMessage(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="grid min-h-dvh place-items-center bg-canvas px-4">
      <form
        onSubmit={onSubmit}
        noValidate
        className="flex w-full max-w-sm flex-col gap-4 rounded-lg border border-line bg-surface p-8"
      >
        <div className="flex flex-col gap-1">
          <h1 className="text-title text-ink">Kelal Studio</h1>
          <p className="text-body-sm text-ink-secondary">Management portal</p>
        </div>

        {error ? <Alert tone="error">{error}</Alert> : null}

        <Field
          label="Email"
          type="email"
          value={email}
          autoComplete="username"
          required
          onChange={(e) => setEmail(e.target.value)}
        />
        <Field
          label="Password"
          type="password"
          value={password}
          autoComplete="current-password"
          required
          onChange={(e) => setPassword(e.target.value)}
        />

        <Button type="submit" disabled={submitting}>
          {submitting ? 'Signing in…' : 'Sign in'}
        </Button>
      </form>
    </main>
  );
}
