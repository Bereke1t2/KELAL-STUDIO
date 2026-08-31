import { useId, type InputHTMLAttributes } from 'react';

/**
 * Labeled text input with a hint slot and an error slot.
 *
 * The design system has no dedicated web text-field node — the mobile field is
 * a Material "notched floating label" (Figma node 52:7). A floating label is a
 * mobile idiom; on a desktop admin form a persistent top label is clearer and
 * screen-reader-friendlier, so this uses one and stays token-faithful.
 *
 * The hint (e.g. accepted formats, min length) is shown BEFORE the user acts,
 * so requirements aren't a surprise on submit. Both hint and error are wired
 * into `aria-describedby`.
 */
interface FieldProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  hint?: string | undefined;
  error?: string | undefined;
}

export function Field({
  label,
  hint,
  error,
  className = '',
  ...rest
}: FieldProps) {
  const id = useId();
  const hintId = `${id}-hint`;
  const errorId = `${id}-error`;
  const describedBy =
    [hint ? hintId : null, error ? errorId : null].filter(Boolean).join(' ') ||
    undefined;

  return (
    <div className="flex flex-col gap-1.5">
      <label htmlFor={id} className="text-label text-ink-secondary">
        {label}
      </label>
      {hint ? (
        <p id={hintId} className="text-caption text-ink-tertiary">
          {hint}
        </p>
      ) : null}
      <input
        id={id}
        // Tie the messages to the input and mark it invalid — a red border
        // alone conveys nothing to a screen reader.
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        className={[
          'min-h-12 rounded-md border bg-surface px-4 text-body text-ink',
          'placeholder:text-ink-tertiary',
          'transition-colors motion-reduce:transition-none',
          error ? 'border-line-error' : 'border-line focus:border-line-focus',
          className,
        ].join(' ')}
        {...rest}
      />
      {error ? (
        <p id={errorId} className="text-body-sm text-error-text">
          {error}
        </p>
      ) : null}
    </div>
  );
}
