import { useTranslation } from 'react-i18next';

interface CompletenessBarProps {
  percentage: number;
}

export function CompletenessBar({ percentage }: CompletenessBarProps) {
  const { t } = useTranslation('profile');
  const clamped = Math.min(100, Math.max(0, Math.round(percentage)));

  const colorClass =
    clamped < 30
      ? 'bg-red-500'
      : clamped < 70
        ? 'bg-amber-500'
        : 'bg-green-500';

  return (
    <div>
      <div className="mb-1 flex items-center justify-between">
        <span className="text-sm font-medium text-gray-700">
          {t('completeness')}
        </span>
        <span className="text-sm font-semibold text-gray-900">{clamped}%</span>
      </div>
      <div className="h-2.5 w-full overflow-hidden rounded-full bg-gray-200">
        <div
          className={`h-full rounded-full transition-all duration-500 ${colorClass}`}
          style={{ width: `${clamped}%` }}
        />
      </div>
    </div>
  );
}
