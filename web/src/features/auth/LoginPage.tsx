import { useState, type FormEvent } from 'react';

import { useAuth } from '../../auth/AuthContext';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Field } from '../../ui/Field';

/**
 * Portal sign-in. Rendered inside <AuthScreen>, which provides the wordmark
 * and the language/theme controls.
 *
 * Temporary shape for this branch: email + password only. The full front door
 * (register, verify email, password reset) and a redesigned sign-in land in
 * `feat/web-self-serve-auth`, stacked on top.
 */
export function LoginPage() {
  const { login } = useAuth();
  const { t } = useTranslation();
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
      // One generic message for wrong password AND unknown email, by design
      // (PRD §6.1) — do not try to be more specific.
      setError(errorMessage(err));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      <div className="flex flex-col gap-1">
        <h1 className="text-title text-ink">{t('login.title')}</h1>
        <p className="text-body-sm text-ink-secondary">{t('login.subtitle')}</p>
      </div>

      {error ? <Alert tone="error">{error}</Alert> : null}

      <Field
        label={t('login.email')}
        type="email"
        value={email}
        autoComplete="username"
        required
        onChange={(e) => setEmail(e.target.value)}
      />
      <Field
        label={t('login.password')}
        type="password"
        value={password}
        autoComplete="current-password"
        required
        onChange={(e) => setPassword(e.target.value)}
      />

      <Button type="submit" block disabled={submitting}>
        {submitting ? t('login.submitting') : t('login.submit')}
      </Button>
    </form>
  );
}
