import { useTranslation } from '../../i18n/I18nContext';
import { Alert } from '../../ui/Alert';

/**
 * There is no GET /admin/users in the contract — the portal cannot list users,
 * so a limit is set by pasting a known user id. Flagged here rather than
 * papered over.
 */
export function MissingRosterNote() {
  const { t } = useTranslation();
  return <Alert tone="info">{t('admin.limits.noRoster')}</Alert>;
}
