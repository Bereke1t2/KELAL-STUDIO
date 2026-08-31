import { useState, type FormEvent } from 'react';

import { ApiError } from '../../api/errors';
import { authApi } from '../../api/endpoints/auth';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Field } from '../../ui/Field';
import { TextLink } from '../../ui/TextLink';
import { AuthHeading } from './AuthHeading';
import { MIN_PASSWORD_LENGTH } from './passwordRules';

/**
 * Create an account.
 *
 * Registration is verification-first and does NOT establish a session
 * (backend/api/openapi.yaml, PRD §11): on success we show a "check your email"
 * panel, not a redirect into the portal. The email must be verified via the
 * link before sign-in works.
 */
export function RegisterPage() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [resent, setResent] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (submitting) return;
    if (password !== confirm) {
      setError(t('field.passwordMismatch'));
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await authApi.register(email, password);
      setDone(true);
    } catch (err) {
      const exists =
        err instanceof ApiError && (err.status === 409 || err.code === 'conflict');
      setError(exists ? t('register.emailExists') : errorMessage(err, t));
      setSubmitting(false);
    }
  }

  if (done) {
    return (
      <div className="flex flex-col gap-5">
        <AuthHeading title={t('register.done.title')} />
        <Alert tone="info">{t('register.done.body', { email })}</Alert>
        {resent ? (
          <p className="text-body-sm text-ink-secondary" role="status">
            {t('register.done.resent')}
          </p>
        ) : (
          <Button
            variant="secondary"
            onClick={() => {
              // Anti-enumeration: always the same acknowledgement, and the
              // request is fire-and-forget (endpoint is always 200).
              void authApi.resendVerification(email).catch(() => {});
              setResent(true);
            }}
          >
            {t('register.done.resend')}
          </Button>
        )}
        <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      <AuthHeading
        title={t('register.title')}
        subtitle={t('register.subtitle')}
      />

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
        autoComplete="new-password"
        required
        minLength={MIN_PASSWORD_LENGTH}
        hint={t('field.passwordHint')}
        onChange={(e) => setPassword(e.target.value)}
      />
      <Field
        label={t('field.confirmPassword')}
        type="password"
        value={confirm}
        autoComplete="new-password"
        required
        onChange={(e) => setConfirm(e.target.value)}
      />

      <Button type="submit" block disabled={submitting}>
        {submitting ? t('register.submitting') : t('register.submit')}
      </Button>

      <div className="border-t border-line-subtle pt-4">
        <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
      </div>
    </form>
  );
}
