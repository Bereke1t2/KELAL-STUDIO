import { useCallback, useEffect, useState } from 'react';

import { brandKitApi } from '../../api/endpoints/brandKit';
import { ApiError } from '../../api/errors';
import type { BrandKit } from '../../api/types';
import { useAuth } from '../../auth/AuthContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Field } from '../../ui/Field';

/**
 * Brand Kit configuration — the portal's primary job (PRD §4, §6.8).
 *
 * FLAG — which id this edits is an OPEN product question
 * (backend/docs/OPEN_QUESTIONS.md, brandkit-creation), not a decision made
 * here. The API offers no way to discover an existing kit's id, so this page
 * addresses the kit at the signed-in user's own id, treating a kit as a
 * per-user singleton. That is one of the options the open item lists, and it
 * is chosen only because a portal that cannot address any kit is useless.
 *
 * The risk it carries, stated plainly: if the mobile app creates a kit at a
 * DIFFERENT id, this page will not find it and PUT will upsert a SECOND kit
 * for the same owner. Both surfaces must agree on the convention before real
 * data exists. Resolve the open item; do not paper over this by adding a
 * discovery heuristic here.
 */
const EMPTY: BrandKit = {
  brand_name: '',
  primary_color_hex: '',
  secondary_color_hex: '',
  tone_of_voice: '',
  contact_info: '',
};

export function BrandKitPage() {
  const { claims } = useAuth();
  const kitId = claims?.sub ?? null;

  const [kit, setKit] = useState<BrandKit>(EMPTY);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!kitId) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    brandKitApi
      .get(kitId)
      .then((k) => {
        if (!cancelled) setKit({ ...EMPTY, ...k });
      })
      .catch((err: unknown) => {
        // 404 is the expected first-run state: no kit exists yet, and the
        // owner-scoped API cannot distinguish that from "not yours". Start a
        // blank form rather than showing the user an error they cannot act on.
        if (err instanceof ApiError && err.status === 404) return;
        if (!cancelled) setError(errorMessage(err));
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [kitId]);

  const set = useCallback(
    (field: keyof BrandKit) => (value: string) => {
      setKit((prev) => ({ ...prev, [field]: value }));
      setSaved(false);
    },
    [],
  );

  async function onSave(): Promise<void> {
    if (!kitId || saving) return;
    setSaving(true);
    setError(null);
    try {
      const next = await brandKitApi.update(kitId, kit);
      setKit({ ...EMPTY, ...next });
      setSaved(true);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  if (!kitId) {
    return (
      <Alert tone="error">
        Your session is missing an account id, so no brand kit can be loaded.
        Sign out and back in.
      </Alert>
    );
  }
  if (loading) return <p className="text-ink-tertiary">Loading brand kit…</p>;

  return (
    <section className="flex max-w-xl flex-col gap-4">
      <div className="flex flex-col gap-1">
        <h1 className="text-2xl">Brand Kit</h1>
        <p className="text-sm text-ink-secondary">
          Pulled into mobile generation automatically on the next session.
        </p>
      </div>

      {error ? <Alert tone="error">{error}</Alert> : null}
      {saved ? <Alert tone="success">Brand kit saved.</Alert> : null}

      <Field
        label="Brand name"
        value={kit.brand_name ?? ''}
        onChange={(e) => set('brand_name')(e.target.value)}
      />
      <Field
        label="Primary color (hex)"
        value={kit.primary_color_hex ?? ''}
        placeholder="#855312"
        onChange={(e) => set('primary_color_hex')(e.target.value)}
      />
      <Field
        label="Secondary color (hex)"
        value={kit.secondary_color_hex ?? ''}
        placeholder="#C6821F"
        onChange={(e) => set('secondary_color_hex')(e.target.value)}
      />
      <Field
        label="Tone of voice"
        value={kit.tone_of_voice ?? ''}
        placeholder="Playful, warm, concise"
        onChange={(e) => set('tone_of_voice')(e.target.value)}
      />
      <Field
        label="Contact info"
        value={kit.contact_info ?? ''}
        onChange={(e) => set('contact_info')(e.target.value)}
      />

      <div>
        <Button onClick={onSave} disabled={saving}>
          {saving ? 'Saving…' : 'Save brand kit'}
        </Button>
      </div>
    </section>
  );
}
