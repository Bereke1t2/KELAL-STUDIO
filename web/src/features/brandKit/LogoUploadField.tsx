import { useRef, useState, type ChangeEvent } from 'react';

import { assetsApi } from '../../api/endpoints/assets';
import type { Asset } from '../../api/types';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';
import { Spinner } from '../../ui/Spinner';

/**
 * Logo upload. `POST /assets` re-encodes and stores the file and returns
 * `{id, width, height, mime_type}` — there is NO GET route, so this shows those
 * facts and an "uploaded" state, never an <img> from the server. The picked
 * `File` is handed up so the preview card can show an unsaved local image.
 *
 * Accepted formats and limits are shown BEFORE the picker so a rejection is not
 * a surprise (PRD §6.8).
 */
export function LogoUploadField({
  assetId,
  onUploaded,
  onCleared,
}: {
  assetId: string | null;
  onUploaded: (id: string, file: File) => void;
  onCleared: () => void;
}) {
  const { t } = useTranslation();
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [meta, setMeta] = useState<{ name: string; asset: Asset } | null>(null);

  async function onPick(e: ChangeEvent<HTMLInputElement>): Promise<void> {
    const file = e.target.files?.[0];
    e.target.value = ''; // allow re-picking the same file
    if (!file) return;
    setUploading(true);
    setError(null);
    try {
      const asset = await assetsApi.upload(file);
      setMeta({ name: file.name, asset });
      if (asset.id) onUploaded(asset.id, file);
    } catch (err) {
      setError(errorMessage(err, t));
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <span className="text-label text-ink-secondary">
        {t('brandKit.logo.label')}
      </span>
      <p className="text-caption text-ink-tertiary">{t('brandKit.logo.limits')}</p>

      <input
        ref={inputRef}
        type="file"
        accept="image/jpeg,image/png"
        onChange={onPick}
        className="sr-only"
      />

      <div className="flex flex-wrap items-center gap-3">
        <Button
          type="button"
          variant="secondary"
          disabled={uploading}
          onClick={() => inputRef.current?.click()}
        >
          {t('brandKit.logo.choose')}
        </Button>

        {uploading ? <Spinner label={t('brandKit.logo.uploading')} /> : null}

        {!uploading && meta ? (
          <p className="text-caption text-ink-secondary">
            {t('brandKit.logo.uploaded', {
              name: meta.name,
              w: meta.asset.width ?? 0,
              h: meta.asset.height ?? 0,
            })}
          </p>
        ) : null}

        {!uploading && !meta && assetId ? (
          <p className="text-caption text-ink-secondary">
            {t('brandKit.logo.onFile')}
          </p>
        ) : null}

        {(meta || assetId) && !uploading ? (
          <Button
            type="button"
            variant="tertiary"
            onClick={() => {
              setMeta(null);
              onCleared();
            }}
          >
            {t('brandKit.logo.remove')}
          </Button>
        ) : null}
      </div>

      {error ? <Alert tone="error">{error}</Alert> : null}
    </div>
  );
}
