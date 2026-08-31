import { useState, type FormEvent } from 'react';

import { authApi } from '../../api/endpoints/auth';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Field } from '../../ui/Field';
import { TextLink } from '../../ui/TextLink';
import { AuthHeading } from './AuthHeading';

/**
 * Request a password-reset link. The endpoint always responds the same way
 * whether or not the email exists (PRD §6.1), so this screen shows one
 * acknowledgement panel regardless — it never implies an account exists.
 */
export function ForgotPasswordPage() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    setError(null);
    try {
      await authApi.requestPasswordReset(email);
      setDone(true);
    } catch (err) {
      // Only a transport failure reaches here — the endpoint itself is always
      // 200. Show the network message, not anything about the account.
      setError(errorMessage(err, t));
      setSubmitting(false);
    }
  }

  if (done) {
    return (
      <div className="flex flex-col gap-5">
        <AuthHeading title={t('forgot.done.title')} />
        <Alert tone="info">{t('forgot.done.body', { email })}</Alert>
        <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} noValidate className="flex flex-col gap-5">
      <AuthHeading title={t('forgot.title')} subtitle={t('forgot.subtitle')} />

      {error ? <Alert tone="error">{error}</Alert> : null}

      <Field
        label={t('field.email')}
        type="email"
        value={email}
        autoComplete="username"
        required
        onChange={(e) => setEmail(e.target.value)}
      />

      <Button type="submit" block disabled={submitting}>
        {t('forgot.submit')}
      </Button>

      <div className="border-t border-line-subtle pt-4">
        <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
      </div>
    </form>
  );
}
