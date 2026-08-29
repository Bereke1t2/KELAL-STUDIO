import { useState } from 'react';

import { useTranslation } from '../i18n/I18nContext';

/**
 * Copy a short value (a user id) to the clipboard, with a brief confirmation.
 * Falls back silently if the Clipboard API is unavailable.
 */
export function CopyButton({ value }: { value: string }) {
  const { t } = useTranslation();
  const [copied, setCopied] = useState(false);

  async function copy(): Promise<void> {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1500);
    } catch {
      // No clipboard access — nothing useful to show.
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      className="min-h-9 rounded-md px-2 text-caption text-tertiary-text hover:bg-brand-subtle"
    >
      {copied ? t('action.copied') : t('action.copy')}
    </button>
  );
}
