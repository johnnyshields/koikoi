import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';

interface PremiumBadgeProps {
  className?: string;
}

export function PremiumBadge({ className = '' }: PremiumBadgeProps) {
  const { t } = useTranslation('billing');
  const navigate = useNavigate();
  const [showTooltip, setShowTooltip] = useState(false);

  return (
    <span className={`relative inline-flex ${className}`}>
      <button
        className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-700 hover:bg-amber-200 transition-colors"
        onClick={() => setShowTooltip(!showTooltip)}
      >
        <svg
          className="h-3 w-3"
          fill="currentColor"
          viewBox="0 0 24 24"
        >
          <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z" />
        </svg>
        {t('premium_feature')}
      </button>
      {showTooltip && (
        <div className="absolute top-full left-1/2 z-10 mt-1 -translate-x-1/2 whitespace-nowrap rounded-lg bg-gray-900 px-3 py-2 text-xs text-white shadow-lg">
          <button
            className="underline"
            onClick={() => navigate('/subscription')}
          >
            {t('upgrade_to_unlock')}
          </button>
        </div>
      )}
    </span>
  );
}
