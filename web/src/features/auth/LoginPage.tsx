import { useState, type FormEvent } from 'react';
import { useLocation, useNavigate } from 'react-router';

import { useAuth } from '../../auth/AuthContext';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Field } from '../../ui/Field';
import { TextLink } from '../../ui/TextLink';
import { AuthHeading } from './AuthHeading';

/** Portal sign-in. Rendered inside <PublicOnlyRoute>'s <AuthScreen>. */
export function LoginPage() {
  const { login } = useAuth();
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from ?? '/brand-kit';

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
      navigate(from, { replace: true });
    } catch (err) {
      // One generic message for wrong password AND unknown email, by design
      // (PRD §6.1) — do not try to be more specific.
      setError(errorMessage(err, t));
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      <AuthHeading title={t('login.title')} subtitle={t('login.subtitle')} />

      {error ? <Alert tone="error">{error}</Alert> : null}

      <Field
        label={t('field.email')}
        type="email"
        value={email}
        autoComplete="username"
        required
        onChange={(e) => setEmail(e.target.value)}
      />
      <Field
        label={t('field.password')}
        type="password"
        value={password}
        autoComplete="current-password"
        required
        onChange={(e) => setPassword(e.target.value)}
      />

      <Button type="submit" block disabled={submitting}>
        {submitting ? t('login.submitting') : t('login.submit')}
      </Button>

      <div className="flex flex-col gap-2 border-t border-line-subtle pt-4">
        <TextLink to="/register">{t('login.toRegister')}</TextLink>
        <TextLink to="/forgot-password">{t('login.toForgot')}</TextLink>
      </div>
    </form>
  );
}
