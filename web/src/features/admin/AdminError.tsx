import { ApiError } from '../../api/errors';
import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';
import { Button } from '../../ui/Button';
import { errorMessage } from '../../ui/errorMessage';

/**
 * Shared error surface for the admin screens.
 *
 * A 403 here means the signed-in account is not an admin — the nav is shown to
 * everyone and the server is the boundary (api/claims.ts). Say that plainly
 * rather than showing a raw "forbidden".
 */
export function AdminError({
  error,
  onRetry,
}: {
  error: unknown;
  onRetry?: () => void;
}) {
  const { t } = useTranslation();
  const forbidden = error instanceof ApiError && error.status === 403;

  return (
    <Alert tone={forbidden ? 'warning' : 'error'}>
      <div className="flex flex-col gap-2">
        <span>{forbidden ? t('admin.forbidden') : errorMessage(error, t)}</span>
        {!forbidden && onRetry ? (
          <Button variant="tertiary" onClick={onRetry} className="self-start px-0">
            {t('action.retry')}
          </Button>
        ) : null}
      </div>
    </Alert>
  );
}
