import { useId, useState } from 'react';

import { useTranslation } from '../../i18n/I18nContext';

type Mode = 'default' | 'block' | 'custom';

function modeOf(value: number | null): Mode {
  if (value === null) return 'default';
  if (value === 0) return 'block';
  return 'custom';
}

/**
 * A per-user daily cap. Three states, because one number input cannot tell
 * "no override" (null) from "blocked" (0):
 *   • Use global default → null   • Block all → 0   • Custom → a positive number
 * Negatives are rejected here and again by the server (400).
 */
export function QuotaField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number | null;
  onChange: (next: number | null) => void;
}) {
  const { t } = useTranslation();
  const name = useId();
  const [custom, setCustom] = useState(
    value && value > 0 ? String(value) : '50',
  );
  const mode = modeOf(value);

  function pick(next: Mode): void {
    if (next === 'default') onChange(null);
    else if (next === 'block') onChange(0);
    else onChange(Math.max(0, parseInt(custom, 10) || 0));
  }

  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="text-label text-ink-secondary">{label}</legend>

      {(['default', 'block', 'custom'] as const).map((m) => (
        <label key={m} className="flex items-center gap-2 text-body-sm text-ink">
          <input
            type="radio"
            name={name}
            checked={mode === m}
            onChange={() => pick(m)}
          />
          <span>{t(`admin.limits.${m}` as const)}</span>
        </label>
      ))}

      {mode === 'custom' ? (
        <input
          type="number"
          min={0}
          inputMode="numeric"
          value={custom}
          onChange={(e) => {
            const raw = e.target.value;
            setCustom(raw);
            const n = parseInt(raw, 10);
            onChange(Number.isFinite(n) && n > 0 ? n : 0);
          }}
          aria-label={t('admin.limits.customValue', { field: label })}
          className="min-h-11 w-32 rounded-md border border-line bg-surface px-3 text-body text-ink"
        />
      ) : null}
    </fieldset>
  );
}
