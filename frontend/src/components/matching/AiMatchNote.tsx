import { useTranslation } from 'react-i18next';
import { AiPersonaBadge } from './AiPersonaBadge';
import type { AiPersona } from '../../api/aiMatchmaker';

interface AiMatchNoteProps {
  note: string;
  persona?: AiPersona;
}

export function AiMatchNote({ note, persona }: AiMatchNoteProps) {
  const { t } = useTranslation('matching');

  return (
    <div className="flex gap-3">
      {/* Avatar */}
      <div className="shrink-0">
        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-violet-100">
          <img
            src={persona?.avatar_url || '/images/ai_cupid_avatar.png'}
            alt="AI Cupid"
            className="h-8 w-8 rounded-full object-cover"
            onError={(e) => {
              const target = e.target as HTMLImageElement;
              target.style.display = 'none';
              target.parentElement!.innerHTML =
                '<span class="text-lg">💘</span>';
            }}
          />
        </div>
      </div>

      {/* Speech bubble */}
      <div className="flex-1">
        <div className="mb-1">
          <AiPersonaBadge persona={persona} size="sm" />
        </div>
        <div className="relative rounded-xl rounded-tl-sm bg-violet-50 px-4 py-3">
          <p className="text-sm leading-relaxed text-violet-900">{note}</p>
          <div className="mt-1.5 flex items-center gap-1">
            <span className="text-[10px] font-medium uppercase tracking-wider text-violet-400">
              {t('ai_rating')}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
