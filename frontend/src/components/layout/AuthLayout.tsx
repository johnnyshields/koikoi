import { Outlet } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Card } from '../ui/Card';

export function AuthLayout() {
  const { t } = useTranslation();

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-b from-rose-50 to-white p-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-4xl font-bold text-rose-600">{t('appName')}</h1>
        </div>
        <Card padding="lg">
          <Outlet />
        </Card>
      </div>
    </div>
  );
}
