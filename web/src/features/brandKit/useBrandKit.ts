import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { brandKitApi } from '../../api/endpoints/brandKit';
import { ApiError } from '../../api/errors';
import type { BrandKit } from '../../api/types';

/**
 * The fields the portal edits, with blanks dropped. `id` / `updated_at` are
 * server-owned and never sent. Dropping blanks keeps the dirty check and the
 * PUT body free of `"": ""` noise.
 */
function editableOf(kit: BrandKit): BrandKit {
  const out: BrandKit = {};
  if (kit.brand_name) out.brand_name = kit.brand_name;
  if (kit.logo_asset_id) out.logo_asset_id = kit.logo_asset_id;
  if (kit.primary_color_hex) out.primary_color_hex = kit.primary_color_hex;
  if (kit.secondary_color_hex) out.secondary_color_hex = kit.secondary_color_hex;
  if (kit.tone_of_voice) out.tone_of_voice = kit.tone_of_voice;
  if (kit.contact_info) out.contact_info = kit.contact_info;
  return out;
}

export interface BrandKitState {
  draft: BrandKit;
  update: (patch: Partial<BrandKit>) => void;
  loading: boolean;
  loadError: unknown;
  saving: boolean;
  saveError: unknown;
  save: () => Promise<void>;
  dirty: boolean;
  savedAt: string | null;
}

/**
 * Load / edit / save the Brand Kit at `id`.
 *
 * FLAG (backend/docs/OPEN_QUESTIONS.md, brandkit-creation): there is no create
 * or discovery endpoint. The caller passes the signed-in user's `sub` and this
 * treats the kit as a per-user singleton. A GET 404 is the first-run state, not
 * an error. If the mobile app created the kit at a different id, PUT here would
 * upsert a SECOND kit for the same owner — unresolved until product picks a
 * creation convention.
 */
export function useBrandKit(id: string): BrandKitState {
  const [server, setServer] = useState<BrandKit>({});
  const [draft, setDraft] = useState<BrandKit>({});
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<unknown>(null);
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<unknown>(null);
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const reqId = useRef(0);

  useEffect(() => {
    const mine = ++reqId.current;
    setLoading(true);
    setLoadError(null);
    brandKitApi
      .get(id)
      .then((kit) => {
        if (mine !== reqId.current) return;
        setServer(kit);
        setDraft(kit);
      })
      .catch((err: unknown) => {
        if (mine !== reqId.current) return;
        if (err instanceof ApiError && err.status === 404) {
          setServer({});
          setDraft({});
        } else {
          setLoadError(err);
        }
      })
      .finally(() => {
        if (mine === reqId.current) setLoading(false);
      });
  }, [id]);

  const update = useCallback((patch: Partial<BrandKit>): void => {
    setDraft((d) => ({ ...d, ...patch }));
    setSavedAt(null);
  }, []);

  const dirty = useMemo(
    () =>
      JSON.stringify(editableOf(draft)) !== JSON.stringify(editableOf(server)),
    [draft, server],
  );

  const save = useCallback(async (): Promise<void> => {
    setSaving(true);
    setSaveError(null);
    try {
      const saved = await brandKitApi.update(id, editableOf(draft));
      setServer(saved);
      setDraft(saved);
      setSavedAt(saved.updated_at ?? new Date().toISOString());
    } catch (err) {
      setSaveError(err);
    } finally {
      setSaving(false);
    }
  }, [id, draft]);

  return {
    draft,
    update,
    loading,
    loadError,
    saving,
    saveError,
    save,
    dirty,
    savedAt,
  };
}
