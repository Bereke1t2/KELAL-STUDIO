import { useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router';

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
 * Set a new password from a `?token=` reset link. The token is single-use
 * server-side; a replayed or expired one comes back as an error and is shown
 * with the server's own wording.
 */
export function ResetPasswordPage() {
  const { t } = useTranslation();
  const [params] = useSearchParams();
  const token = params.get('token');

  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  if (!token) {
    return (
      <div className="flex flex-col gap-5">
        <AuthHeading title={t('reset.noToken.title')} />
        <Alert tone="warning">{t('reset.noToken.body')}</Alert>
        <TextLink to="/forgot-password">{t('reset.requestNew')}</TextLink>
      </div>
    );
  }

  if (done) {
    return (
      <div className="flex flex-col gap-5">
        <AuthHeading title={t('reset.success.title')} />
        <Alert tone="success">{t('reset.success.body')}</Alert>
        <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
      </div>
    );
  }

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (submitting || !token) return;
    if (password !== confirm) {
      setError(t('field.passwordMismatch'));
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await authApi.confirmPasswordReset(token, password);
      setDone(true);
    } catch (err) {
      setError(errorMessage(err, t));
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      <AuthHeading title={t('reset.title')} subtitle={t('reset.subtitle')} />

      {error ? <Alert tone="error">{error}</Alert> : null}

      <Field
        label={t('field.newPassword')}
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
        {submitting ? t('reset.submitting') : t('reset.submit')}
      </Button>

      <div className="border-t border-line-subtle pt-4">
        <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
      </div>
    </form>
  );
}
