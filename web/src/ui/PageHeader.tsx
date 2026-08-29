import type { ReactNode } from 'react';

/**
 * Screen title block.
 *
 * The eyebrow is a structural device, not decoration: it names the section
 * group ("Brand" / "Oversight") so the reader always knows which half of the
 * portal they are in. Hierarchy is size + colour + tracking — the system has
 * one weight.
 */
export function PageHeader({
  eyebrow,
  title,
  description,
  actions,
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  actions?: ReactNode;
}) {
  return (
    <header className="flex flex-wrap items-start justify-between gap-4 border-b border-line-subtle pb-6">
      <div className="flex flex-col gap-2">
        {eyebrow ? (
          <span className="text-caption uppercase tracking-[0.12em] text-ink-tertiary">
            {eyebrow}
          </span>
        ) : null}
        <h1 className="text-display text-ink">{title}</h1>
        {description ? (
          <p className="max-w-[58ch] text-body-sm text-ink-secondary">
            {description}
          </p>
        ) : null}
      </div>
      {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
    </header>
  );
}
