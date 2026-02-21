import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { AiPersonaBadge } from '../../components/matching/AiPersonaBadge';
import { AiMatchNote } from '../../components/matching/AiMatchNote';
import { aiMatchmakerApi } from '../../api/aiMatchmaker';
import type { AiPersona, AiRating } from '../../api/aiMatchmaker';
import { useSocialStore } from '../../store/social';

const MATCHMAKERS_REQUIRED = 2;

export function ColdStartPage() {
  const { t } = useTranslation('matching');
  const navigate = useNavigate();

  const { socialStatus, fetchSocialStatus } = useSocialStore();
  const [persona, setPersona] = useState<AiPersona | null>(null);
  const [aiRatings, setAiRatings] = useState<AiRating[]>([]);
  const [isTriggering, setIsTriggering] = useState(false);
  const [triggered, setTriggered] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadData();
  }, []);

  // Redirect if matchmaking is active
  useEffect(() => {
    if (socialStatus?.matchmaking_active) {
      navigate('/matching', { replace: true });
    }
  }, [socialStatus, navigate]);

  async function loadData() {
    setIsLoading(true);
    try {
      const [personaRes, ratingsRes] = await Promise.all([
        aiMatchmakerApi.getPersona(),
        aiMatchmakerApi.getAiRatings(),
      ]);
      setPersona(personaRes.data.persona);
      setAiRatings(ratingsRes.data.ratings);

      await fetchSocialStatus();
    } catch {
      // Ignore errors on load
    } finally {
      setIsLoading(false);
    }
  }

  async function handleTriggerAi() {
    setIsTriggering(true);
    try {
      await aiMatchmakerApi.triggerColdStart();
      setTriggered(true);
      // Refresh ratings after a short delay to allow processing
      setTimeout(async () => {
        const res = await aiMatchmakerApi.getAiRatings();
        setAiRatings(res.data.ratings);
      }, 2000);
    } catch {
      // Ignore errors
    } finally {
      setIsTriggering(false);
    }
  }

  const matchmakerCount = socialStatus?.matchmaker_count ?? 0;
  const progressPercent = Math.min((matchmakerCount / MATCHMAKERS_REQUIRED) * 100, 100);

  if (isLoading) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-rose-500 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="space-y-6 pb-8">
      {/* Header */}
      <div className="text-center">
        <h1 className="text-xl font-bold text-gray-900">
          {t('cold_start_title')}
        </h1>
        <p className="mt-2 text-sm text-gray-500">
          {t('cold_start_description')}
        </p>
      </div>

      {/* AI Cupid intro */}
      <Card>
        <div className="flex flex-col items-center text-center">
          <div className="mb-3 flex h-16 w-16 items-center justify-center rounded-full bg-violet-100">
            <img
              src={persona?.avatar_url || '/images/ai_cupid_avatar.png'}
              alt="AI Cupid"
              className="h-12 w-12 rounded-full object-cover"
              onError={(e) => {
                const target = e.target as HTMLImageElement;
                target.style.display = 'none';
                target.parentElement!.innerHTML = '<span class="text-3xl">💘</span>';
              }}
            />
          </div>
          <AiPersonaBadge persona={persona ?? undefined} size="md" />
          <p className="mt-3 text-sm text-gray-600">
            {t('ai_cupid_intro')}
          </p>
        </div>
      </Card>

      {/* Matchmaker progress */}
      <Card>
        <h2 className="mb-3 text-base font-semibold text-gray-900">
          {t('invite_matchmakers_progress', {
            count: matchmakerCount,
            required: MATCHMAKERS_REQUIRED,
          })}
        </h2>

        {/* Progress bar */}
        <div className="mb-4 h-3 w-full overflow-hidden rounded-full bg-gray-100">
          <div
            className="h-full rounded-full bg-rose-500 transition-all duration-500"
            style={{ width: `${progressPercent}%` }}
          />
        </div>

        {/* Invite button */}
        <Button
          variant="outline"
          fullWidth
          onClick={() => navigate('/invite')}
        >
          {t('cold_start_title')}
        </Button>
      </Card>

      {/* AI Analysis trigger */}
      <Card>
        <div className="text-center">
          <Button
            variant="primary"
            fullWidth
            isLoading={isTriggering}
            disabled={triggered}
            onClick={handleTriggerAi}
          >
            {triggered ? t('ai_analysis_complete') : t('trigger_ai_analysis')}
          </Button>
        </div>
      </Card>

      {/* AI Ratings list */}
      {aiRatings.length > 0 && (
        <div className="space-y-3">
          <h2 className="text-base font-semibold text-gray-900">
            {t('ai_rating')}
          </h2>
          {aiRatings.map((rating) => (
            <Card key={rating.id} padding="sm">
              <AiMatchNote
                note={rating.signals?.matchmaker_note || t('ai_cupid_intro')}
                persona={persona ?? undefined}
              />
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
