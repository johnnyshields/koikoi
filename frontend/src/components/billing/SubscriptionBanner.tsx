import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Button } from '../ui/Button';

interface SubscriptionBannerProps {
  className?: string;
}

export function SubscriptionBanner({ className = '' }: SubscriptionBannerProps) {
  const { t } = useTranslation('billing');
  const navigate = useNavigate();
  const [dismissed, setDismissed] = useState(false);

  if (dismissed) return null;

  return (
    <div
      className={`relative rounded-lg bg-gradient-to-r from-rose-50 to-pink-50 border border-rose-200 px-4 py-3 ${className}`}
    >
      <button
        className="absolute top-2 right-2 text-gray-400 hover:text-gray-600"
        onClick={() => setDismissed(true)}
        aria-label="Close"
      >
        <svg
          className="h-4 w-4"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      </button>
      <div className="pr-6">
        <p className="text-sm font-medium text-rose-800">
          {t('subscription_needed')}
        </p>
        <Button
          size="sm"
          className="mt-2"
          onClick={() => navigate('/subscription')}
        >
          {t('upgrade')}
        </Button>
      </div>
    </div>
  );
}
