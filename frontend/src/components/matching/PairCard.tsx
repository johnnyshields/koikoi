import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import type { PairPerson } from '../../types';

interface PairCardProps {
  person: PairPerson;
  side: 'left' | 'right';
}

export function PairCard({ person, side }: PairCardProps) {
  const { t } = useTranslation('matching');
  const [expanded, setExpanded] = useState(false);

  const photoUrl = person.primary_photo?.url;
  const completenessPercent = Math.round(person.profile_completeness * 100);

  return (
    <div
      className={`relative flex-1 cursor-pointer overflow-hidden rounded-2xl bg-white shadow-md transition-all duration-300 ${
        expanded ? 'z-10 scale-[1.02]' : ''
      } ${side === 'left' ? 'origin-right' : 'origin-left'}`}
      onClick={() => setExpanded(!expanded)}
    >
      {/* Photo area */}
      <div className="relative aspect-[3/4] w-full overflow-hidden bg-gray-100">
        {photoUrl ? (
          <img
            src={photoUrl}
            alt={person.nickname}
            className="h-full w-full object-cover"
          />
        ) : (
          <div className="flex h-full items-center justify-center">
            <div className="flex h-20 w-20 items-center justify-center rounded-full bg-rose-100 text-3xl font-bold text-rose-400">
              {person.nickname.slice(0, 1)}
            </div>
          </div>
        )}

        {/* Gradient overlay */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />

        {/* Name overlay */}
        <div className="absolute bottom-0 left-0 right-0 p-3">
          <h3 className="text-lg font-bold text-white drop-shadow-md">
            {person.nickname}
          </h3>
          <div className="flex items-center gap-2 text-sm text-white/90">
            {person.age && <span>{person.age}</span>}
            {person.age && person.prefecture && <span>·</span>}
            {person.prefecture && <span>{person.prefecture}</span>}
          </div>
        </div>

        {/* Profile completeness indicator */}
        <div className="absolute top-2 right-2">
          <div
            className="flex h-8 w-8 items-center justify-center rounded-full text-[10px] font-bold shadow-sm"
            style={{
              background: `conic-gradient(rgb(244 63 94) ${completenessPercent}%, rgb(229 231 235) 0)`,
            }}
          >
            <div className="flex h-6 w-6 items-center justify-center rounded-full bg-white text-gray-600">
              {completenessPercent}
            </div>
          </div>
        </div>
      </div>

      {/* Tags */}
      <div className="p-3">
        <div className="flex gap-1.5 overflow-x-auto scrollbar-hide">
          {person.tags.slice(0, expanded ? undefined : 3).map((tag) => (
            <span
              key={`${tag.category}-${tag.value}`}
              className="shrink-0 rounded-full bg-rose-50 px-2.5 py-1 text-xs text-rose-600"
            >
              {tag.value}
            </span>
          ))}
          {!expanded && person.tags.length > 3 && (
            <span className="shrink-0 rounded-full bg-gray-50 px-2.5 py-1 text-xs text-gray-400">
              +{person.tags.length - 3}
            </span>
          )}
        </div>
      </div>

      {/* Expanded details */}
      {expanded && (
        <div className="border-t border-gray-100 p-3 text-sm text-gray-600">
          {!photoUrl && (
            <p className="mb-1 text-xs text-gray-400">{t('no_photo')}</p>
          )}
          {person.tags.length === 0 && (
            <p className="text-xs text-gray-400">-</p>
          )}
        </div>
      )}
    </div>
  );
}
