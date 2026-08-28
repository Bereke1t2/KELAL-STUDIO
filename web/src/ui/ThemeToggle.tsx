import { useTheme, type ThemePreference } from '../theme/ThemeContext';

const OPTIONS: ReadonlyArray<{ value: ThemePreference; label: string }> = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'system', label: 'System' },
];

/**
 * Light / Dark / System selector.
 *
 * 'System' is a real third option, not a default the other two overwrite —
 * choosing it hands control back to the OS and keeps tracking it live.
 * Rendered as a native <select> so it is keyboard- and screen-reader-correct
 * without reimplementing listbox semantics.
 */
export function ThemeToggle() {
  const { preference, setPreference } = useTheme();

  return (
    <label className="flex items-center gap-2 text-sm text-ink-secondary">
      <span>Theme</span>
      <select
        value={preference}
        onChange={(e) => setPreference(e.target.value as ThemePreference)}
        className="min-h-12 rounded-md border border-line bg-surface px-3 text-ink"
      >
        {OPTIONS.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </label>
  );
}
