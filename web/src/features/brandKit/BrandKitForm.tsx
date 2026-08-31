import type { BrandKit } from '../../api/types';
import { useTranslation } from '../../i18n/I18nContext';
import { isHex, normalizeHex } from '../../lib/hex';
import { Field } from '../../ui/Field';
import { LogoUploadField } from './LogoUploadField';

/**
 * Controlled Brand Kit form. Holds no state of its own — `draft` and `update`
 * come from `useBrandKit`, and every keystroke flows straight to the live
 * preview.
 */
export function BrandKitForm({
  draft,
  update,
  onLogoFile,
}: {
  draft: BrandKit;
  update: (patch: Partial<BrandKit>) => void;
  onLogoFile: (file: File | null) => void;
}) {
  const { t } = useTranslation();

  return (
    <div className="flex flex-col gap-6">
      <Field
        label={t('brandKit.field.name')}
        value={draft.brand_name ?? ''}
        onChange={(e) => update({ brand_name: e.target.value })}
      />

      <HexField
        label={t('brandKit.field.primary')}
        value={draft.primary_color_hex ?? ''}
        onChange={(v) => update({ primary_color_hex: v })}
        invalidHint={t('brandKit.field.hexHint')}
      />
      <HexField
        label={t('brandKit.field.secondary')}
        value={draft.secondary_color_hex ?? ''}
        onChange={(v) => update({ secondary_color_hex: v })}
        invalidHint={t('brandKit.field.hexHint')}
      />

      <Field
        label={t('brandKit.field.tone')}
        value={draft.tone_of_voice ?? ''}
        hint={t('brandKit.field.toneHint')}
        onChange={(e) => update({ tone_of_voice: e.target.value })}
      />
      <Field
        label={t('brandKit.field.contact')}
        value={draft.contact_info ?? ''}
        onChange={(e) => update({ contact_info: e.target.value })}
      />

      <LogoUploadField
        assetId={draft.logo_asset_id ?? null}
        onUploaded={(id, file) => {
          update({ logo_asset_id: id });
          onLogoFile(file);
        }}
        onCleared={() => {
          update({ logo_asset_id: null });
          onLogoFile(null);
        }}
      />
    </div>
  );
}

function HexField({
  label,
  value,
  onChange,
  invalidHint,
}: {
  label: string;
  value: string;
  onChange: (next: string) => void;
  invalidHint: string;
}) {
  const showHint = value.trim() !== '' && !isHex(value);
  const swatch = normalizeHex(value) ?? '#855312';

  return (
    <div className="flex items-end gap-3">
      <Field
        label={label}
        value={value}
        placeholder="#1a2b3c"
        error={showHint ? invalidHint : undefined}
        onChange={(e) => onChange(e.target.value)}
        className="flex-1"
      />
      <label className="mb-0.5 shrink-0">
        <span className="sr-only">{label}</span>
        <input
          type="color"
          value={swatch}
          onChange={(e) => onChange(e.target.value)}
          className="size-12 cursor-pointer rounded-md border border-line bg-surface"
        />
      </label>
    </div>
  );
}
