import { useTranslation } from 'react-i18next';
import type { AiPersona } from '../../api/aiMatchmaker';

interface AiPersonaBadgeProps {
  persona?: AiPersona;
  size?: 'sm' | 'md';
}

export function AiPersonaBadge({ persona, size = 'sm' }: AiPersonaBadgeProps) {
  const { i18n } = useTranslation();
  const isJa = i18n.language === 'ja';

  const name = persona
    ? isJa
      ? persona.name_ja
      : persona.name_en
    : isJa
      ? '恋のキューピッド'
      : "Love's Cupid";

  const avatarUrl = persona?.avatar_url || '/images/ai_cupid_avatar.png';

  const sizeClasses = size === 'sm'
    ? 'gap-1.5 px-2 py-1 text-xs'
    : 'gap-2 px-3 py-1.5 text-sm';

  const imgSize = size === 'sm' ? 'h-4 w-4' : 'h-5 w-5';

  return (
    <span
      className={`inline-flex items-center rounded-full bg-violet-50 text-violet-700 font-medium ${sizeClasses}`}
    >
      <img
        src={avatarUrl}
        alt={name}
        className={`${imgSize} rounded-full object-cover`}
        onError={(e) => {
          (e.target as HTMLImageElement).style.display = 'none';
        }}
      />
      <span>{name}</span>
      <span className="text-violet-400">AI</span>
    </span>
  );
}
