import { useId, type InputHTMLAttributes } from 'react';

/**
 * Labeled text input with an error slot.
 *
 * The design system has no dedicated Text Field component node — the real
 * "notched floating label" field lives in Screens / Onboarding & Auth (node
 * 52:7), which is Material's outlined-input behavior. A floating label is a
 * mobile idiom; on a desktop admin form a persistent top label is clearer and
 * screen-reader-friendlier, so this uses one and stays token-faithful rather
 * than copying the mobile shape. Revisit if a web field is added to Figma.
 */
interface FieldProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string | undefined;
}

export function Field({ label, error, className = '', ...rest }: FieldProps) {
  const id = useId();
  const errorId = `${id}-error`;

  return (
    <div className="flex flex-col gap-2">
      <label htmlFor={id} className="text-sm text-ink-secondary">
        {label}
      </label>
      <input
        id={id}
        // Tie the message to the input so it is announced, and mark the field
        // invalid — a red border alone conveys nothing to a screen reader.
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? errorId : undefined}
        className={[
          'min-h-12 rounded-md border bg-surface px-4 py-3 text-ink',
          'placeholder:text-ink-tertiary',
          error ? 'border-line-error' : 'border-line',
          className,
        ].join(' ')}
        {...rest}
      />
      {error ? (
        <p id={errorId} className="text-sm text-error-text">
          {error}
        </p>
      ) : null}
    </div>
  );
}
