import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';

export function PaymentSuccessPage() {
  const { t } = useTranslation('billing');
  const navigate = useNavigate();

  return (
    <div className="flex items-center justify-center py-12">
      <Card className="max-w-sm text-center">
        {/* Success checkmark */}
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-green-100">
          <svg
            className="h-8 w-8 text-green-600"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M5 13l4 4L19 7"
            />
          </svg>
        </div>
        <h1 className="text-xl font-bold text-gray-900">
          {t('payment_success')}
        </h1>
        <p className="mt-2 text-sm text-gray-500">{t('payment_success_sub')}</p>
        <Button fullWidth className="mt-6" onClick={() => navigate('/')}>
          {t('return_to_app')}
        </Button>
      </Card>
    </div>
  );
}
