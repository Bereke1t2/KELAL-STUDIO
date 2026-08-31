/**
 * Renders untrusted user-authored text — a flagged prompt snapshot — as
 * PLAIN TEXT ONLY.
 *
 * These strings are effectively unannounced business plans (PRD §7.9): a
 * competitor-sensitive "50% off starting Friday" is exactly the kind of thing
 * that trips a moderation filter. So: never `dangerouslySetInnerHTML`, never
 * auto-link a URL, never send it to a third party. React escapes `{text}`;
 * that is the whole point.
 *
 * `lang="am"` + the Ethiopic face because a snapshot is very likely Amharic;
 * Latin runs fall back cleanly within that stack.
 */
export function ConfidentialText({
  text,
  className = '',
}: {
  text: string;
  className?: string;
}) {
  return (
    <blockquote
      lang="am"
      className={`border-l-2 border-line-strong bg-canvas px-3 py-2 font-ethiopic text-body-sm leading-body whitespace-pre-wrap break-words text-ink ${className}`}
    >
      {text}
    </blockquote>
  );
}
