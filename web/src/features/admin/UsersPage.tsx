import { useState, type FormEvent } from 'react';

import { adminApi } from '../../api/endpoints/admin';
import type { SetUserLimitsRequest } from '../../api/types';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { Field } from '../../ui/Field';
import { PageHeader } from '../../ui/PageHeader';
import { AdminError } from './AdminError';
import { MissingRosterNote } from './MissingRosterNote';
import { QuotaField } from './QuotaField';

/**
 * Per-user daily generation caps (PRD §6.13, §6.14).
 *
 * Raising a cap spends the beta's *shared* provider budget — this is a
 * financial control, not a neutral preference, and the copy says so.
 */
export function UsersPage() {
  const { t } = useTranslation();
  const [userId, setUserId] = useState('');
  const [text, setText] = useState<number | null>(null);
  const [image, setImage] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<unknown>(null);
  const [savedFor, setSavedFor] = useState<string | null>(null);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (saving || !userId.trim()) return;
    setSaving(true);
    setError(null);
    setSavedFor(null);
    const body: SetUserLimitsRequest = {
      daily_text_quota: text,
      daily_image_quota: image,
    };
    try {
      const result = await adminApi.setUserLimits(userId.trim(), body);
      setSavedFor(result.user_id ?? userId.trim());
    } catch (err) {
      setError(err);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        eyebrow={t('nav.group.oversight')}
        title={t('nav.users')}
        description={t('admin.limits.description')}
      />

      <MissingRosterNote />

      <form onSubmit={onSubmit} noValidate className="flex flex-col gap-6">
        <Field
          label={t('admin.limits.userId')}
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          placeholder="00000000-0000-0000-0000-000000000000"
          className="font-mono"
          required
        />

        <QuotaField
          label={t('admin.limits.textCap')}
          value={text}
          onChange={setText}
        />
        <QuotaField
          label={t('admin.limits.imageCap')}
          value={image}
          onChange={setImage}
        />

        {error ? <AdminError error={error} /> : null}
        {savedFor ? (
          <Alert tone="success">
            {t('admin.limits.saved', { id: savedFor })}
          </Alert>
        ) : null}

        <div className="border-t border-line-subtle pt-4">
          <Button type="submit" disabled={saving || !userId.trim()}>
            {saving ? t('action.saving') : t('admin.limits.apply')}
          </Button>
        </div>
      </form>
    </div>
  );
}
