import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router';

import { authApi } from '../../api/endpoints/auth';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { Field } from '../../ui/Field';
import { Spinner } from '../../ui/Spinner';
import { TextLink } from '../../ui/TextLink';
import { AuthHeading } from './AuthHeading';

type Stage = 'verifying' | 'ok' | 'bad' | 'no-token';

/**
 * Consumes a verification token from `?token=` and marks the email verified.
 * Idempotent server-side. With no token (or a bad one) it falls back to a
 * resend-by-email form.
 */
export function VerifyEmailPage() {
  const { t } = useTranslation();
  const [params] = useSearchParams();
  const token = params.get('token');

  const [stage, setStage] = useState<Stage>(token ? 'verifying' : 'no-token');
  const ran = useRef(false);

  useEffect(() => {
    if (!token || ran.current) return;
    ran.current = true; // StrictMode double-invokes effects in dev.
    authApi
      .verifyEmail(token)
      .then(() => setStage('ok'))
      .catch(() => setStage('bad'));
  }, [token]);

  if (stage === 'verifying') {
    return (
      <div className="flex flex-col gap-5">
        <AuthHeading title={t('verify.title')} />
        <Spinner label={t('verify.verifying')} />
      </div>
    );
  }

  if (stage === 'ok') {
    return (
      <div className="flex flex-col gap-5">
        <AuthHeading title={t('verify.success.title')} />
        <Alert tone="success">{t('verify.success.body')}</Alert>
        <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
      </div>
    );
  }

  // 'bad' or 'no-token' — offer a fresh link.
  return <ResendForm invalid={stage === 'bad'} />;
}

function ResendForm({ invalid }: { invalid: boolean }) {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (submitting) return;
    setSubmitting(true);
    // Always the same acknowledgement regardless of outcome (anti-enumeration,
    // and the endpoint is always 200).
    await authApi.resendVerification(email).catch(() => {});
    setSent(true);
    setSubmitting(false);
  }

  return (
    <div className="flex flex-col gap-5">
      <AuthHeading
        title={invalid ? t('verify.invalid.title') : t('verify.title')}
      />
      {invalid ? (
        <Alert tone="warning">{t('verify.invalid.body')}</Alert>
      ) : (
        <p className="text-body-sm text-ink-secondary">{t('verify.needEmail')}</p>
      )}

      {sent ? (
        <p className="text-body-sm text-ink-secondary" role="status">
          {t('verify.resend.sent')}
        </p>
      ) : (
        <form onSubmit={onSubmit} noValidate className="flex flex-col gap-4">
          <Field
            label={t('field.email')}
            type="email"
            value={email}
            autoComplete="username"
            required
            onChange={(e) => setEmail(e.target.value)}
          />
          <Button type="submit" block disabled={submitting}>
            {t('verify.resend.submit')}
          </Button>
        </form>
      )}

      <TextLink to="/login">{t('auth.backToLogin')}</TextLink>
    </div>
  );
}
