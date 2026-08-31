/**
 * Loading indicator. The ring animates; under `prefers-reduced-motion` it
 * holds still and the adjacent status text carries the meaning.
 */
export function Spinner({
  label,
  className = '',
}: {
  label: string;
  className?: string;
}) {
  return (
    <span
      role="status"
      className={`inline-flex items-center gap-3 text-body-sm text-ink-secondary ${className}`}
    >
      <span
        aria-hidden
        className="size-4 animate-spin rounded-full border-2 border-line border-t-primary motion-reduce:animate-none"
      />
      {label}
    </span>
  );
}
