import type { ReactNode } from 'react';

/**
 * Feedback banner — Figma `Color — Feedback` (node 11:4), documented in-file
 * as powering the Toast/Banner and Badge components directly.
 *
 * Every failure the portal shows should land here rather than in a bare
 * string, so the PRD's "plain-language guidance, never a raw technical error"
 * bar (§6.4, acceptance criterion 7) has one place to be enforced.
 */
export type AlertTone = 'success' | 'warning' | 'error' | 'info';

const TONES: Record<AlertTone, string> = {
  success: 'bg-success-bg border-success-line text-success-text',
  warning: 'bg-warning-bg border-warning-line text-warning-text',
  error: 'bg-error-bg border-error-line text-error-text',
  info: 'bg-info-bg border-info-line text-info-text',
};

export function Alert({
  tone = 'info',
  children,
}: {
  tone?: AlertTone;
  children: ReactNode;
}) {
  return (
    <div
      // Errors interrupt; the rest are announced politely when convenient.
      role={tone === 'error' ? 'alert' : 'status'}
      className={`rounded-md border px-4 py-3 text-sm ${TONES[tone]}`}
    >
      {children}
    </div>
  );
}
