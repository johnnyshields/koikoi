import { useTranslation } from 'react-i18next';
import type { ProfileTag } from '../../types';

interface SharedTagsBadgeProps {
  tags: ProfileTag[];
}

export function SharedTagsBadge({ tags }: SharedTagsBadgeProps) {
  const { t } = useTranslation('matching');

  if (tags.length === 0) return null;

  return (
    <div className="flex flex-col items-center gap-1.5 py-2">
      {/* Connector line */}
      <div className="h-4 w-px bg-rose-200" />

      {/* Heart icon */}
      <div className="flex h-8 w-8 items-center justify-center rounded-full bg-rose-100">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-4 w-4 text-rose-500"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fillRule="evenodd"
            d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z"
            clipRule="evenodd"
          />
        </svg>
      </div>

      {/* Header */}
      <span className="text-xs font-medium text-rose-500">
        {t('shared_tags')}
      </span>

      {/* Tag pills */}
      <div className="flex max-w-[200px] flex-wrap justify-center gap-1">
        {tags.slice(0, 5).map((tag) => (
          <span
            key={`${tag.category}-${tag.value}`}
            className="animate-pulse-slow rounded-full bg-rose-500 px-2 py-0.5 text-[11px] font-medium text-white shadow-sm"
          >
            {tag.value}
          </span>
        ))}
        {tags.length > 5 && (
          <span className="rounded-full bg-rose-200 px-2 py-0.5 text-[11px] font-medium text-rose-600">
            +{tags.length - 5}
          </span>
        )}
      </div>

      {/* Connector line */}
      <div className="h-4 w-px bg-rose-200" />
    </div>
  );
}
