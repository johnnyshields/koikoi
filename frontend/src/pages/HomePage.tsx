import { useTranslation } from 'react-i18next';
import { useAuth } from '../hooks/useAuth';
import { Card } from '../components/ui/Card';
import { Button } from '../components/ui/Button';

export function HomePage() {
  const { t } = useTranslation();
  const { user, logout } = useAuth();

  return (
    <div className="space-y-4">
      <Card>
        <h2 className="mb-2 text-xl font-semibold text-gray-900">
          {t('welcome.title')}
        </h2>
        <p className="text-gray-600">{t('welcome.subtitle')}</p>
      </Card>

      {user && (
        <Card>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">{user.phone_number}</p>
              {!user.phone_verified && (
                <p className="mt-1 text-xs text-amber-600">
                  {t('errors.unauthorized')}
                </p>
              )}
            </div>
            <Button variant="outline" size="sm" onClick={() => logout()}>
              {t('auth:logout', { defaultValue: t('actions.submit') })}
            </Button>
          </div>
        </Card>
      )}
    </div>
  );
}
