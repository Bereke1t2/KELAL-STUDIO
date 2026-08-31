import { useState, type FormEvent } from 'react';

import { adminApi } from '../../api/endpoints/admin';
import { ApiError } from '../../api/errors';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Field } from '../../ui/Field';
import { NotBuilt } from './NotBuilt';

/**
 * Per-user quota limits (PRD §6.13, §6.14, acceptance criterion 16).
 *
 * FLAG — there is no list-users endpoint. backend/api/openapi.yaml exposes
 * PUT /admin/users/{id}/limits and nothing that enumerates users, so this
 * screen cannot show a roster and asks for an account id instead. That is a
 * gap in the admin surface, not a UX preference: add GET /admin/users when
 * the Admin slice is built and replace this input with a real list.
 *
 * Quota is a financial control, not a preference — provider rate limits are
 * enforced per ACCOUNT globally, so one user can drain the whole beta
 * population's daily budget (§12). Raising a limit here spends shared
 * capacity, which is why the form states it rather than presenting the
 * numbers as neutral settings.
 */
export function UsersPage() {
  const [userId, setUserId] = useState('');
  const [textLimit, setTextLimit] = useState('');
  const [imageLimit, setImageLimit] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [notBuilt, setNotBuilt] = useState(false);
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);

  async function onSubmit(e: FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault();
    if (saving) return;
    setSaving(true);
    setError(null);
    setNotBuilt(false);
    setSaved(false);
    try {
      await adminApi.setUserLimits(userId.trim(), {
        text_calls_limit: Number(textLimit),
        image_calls_limit: Number(imageLimit),
      });
      setSaved(true);
    } catch (err) {
      if (err instanceof ApiError && err.isNotImplemented) setNotBuilt(true);
      else setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="flex max-w-xl flex-col gap-4">
      <div className="flex flex-col gap-1">
        <h1 className="text-2xl">User limits</h1>
        <p className="text-sm text-ink-secondary">
          Daily generation caps. These spend a shared provider budget — raising
          one user’s limit reduces what remains for everyone else.
        </p>
      </div>

      {notBuilt ? <NotBuilt slice="Admin user limits" /> : null}
      {error ? <Alert tone="error">{error}</Alert> : null}
      {saved ? <Alert tone="success">Limits updated.</Alert> : null}

      <form onSubmit={onSubmit} className="flex flex-col gap-4">
        <Field
          label="Account id"
          value={userId}
          required
          placeholder="UUID — no user list endpoint exists yet"
          onChange={(e) => setUserId(e.target.value)}
        />
        <Field
          label="Text generations per day"
          type="number"
          min={0}
          value={textLimit}
          required
          onChange={(e) => setTextLimit(e.target.value)}
        />
        <Field
          label="Image generations per day"
          type="number"
          min={0}
          value={imageLimit}
          required
          onChange={(e) => setImageLimit(e.target.value)}
        />
        <div>
          <Button type="submit" disabled={saving}>
            {saving ? 'Saving…' : 'Update limits'}
          </Button>
        </div>
      </form>
    </section>
  );
}
