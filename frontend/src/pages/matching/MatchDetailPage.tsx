import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useParams, useNavigate } from 'react-router-dom';
import { matchingApi } from '../../api/matching';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';
import type { Match } from '../../types';

const STATUS_COLORS: Record<string, string> = {
  pending_intro: 'bg-amber-100 text-amber-700',
  introduced: 'bg-blue-100 text-blue-700',
  chatting: 'bg-green-100 text-green-700',
  expired: 'bg-gray-100 text-gray-500',
  declined: 'bg-red-100 text-red-600',
};

export function MatchDetailPage() {
  const { t } = useTranslation('matching');
  const { t: tc } = useTranslation('common');
  const { matchId } = useParams<{ matchId: string }>();
  const navigate = useNavigate();
  const [match, setMatch] = useState<Match | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isResponding, setIsResponding] = useState(false);

  useEffect(() => {
    if (!matchId) return;
    setIsLoading(true);
    matchingApi
      .getMatch(matchId)
      .then(({ data }) => setMatch(data.match))
      .catch(() => toast(tc('errors.generic'), 'error'))
      .finally(() => setIsLoading(false));
  }, [matchId, tc]);

  const handleRespond = async (response: 'accepted' | 'declined') => {
    if (!matchId) return;
    setIsResponding(true);
    try {
      const { data } = await matchingApi.respondToMatch(matchId, response);
      setMatch(data.match);
      toast(
        response === 'accepted' ? t('accept_intro') : t('decline_intro'),
        response === 'accepted' ? 'success' : 'info',
      );
    } catch {
      toast(tc('errors.generic'), 'error');
    } finally {
      setIsResponding(false);
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (!match) {
    return (
      <Card>
        <p className="text-center text-gray-500">{tc('errors.notFound')}</p>
      </Card>
    );
  }

  const statusColor = STATUS_COLORS[match.status] || 'bg-gray-100 text-gray-500';
  const isPending = match.status === 'pending_intro';
  const isChatting = match.status === 'chatting';
  const scorePercent = Math.round(match.compatibility_score * 100);

  return (
    <div className="space-y-4 pb-4">
      {/* Back button */}
      <button
        type="button"
        onClick={() => navigate('/matches')}
        className="flex items-center gap-1 text-sm text-gray-500 hover:text-gray-700"
      >
        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clipRule="evenodd" />
        </svg>
        {tc('actions.back')}
      </button>

      {/* Compatibility score - large, prominent */}
      <Card>
        <div className="flex flex-col items-center gap-2 py-4">
          <div className="relative flex h-28 w-28 items-center justify-center">
            <svg className="h-full w-full -rotate-90" viewBox="0 0 100 100">
              <circle cx="50" cy="50" r="42" fill="none" stroke="#f3f4f6" strokeWidth="8" />
              <circle
                cx="50"
                cy="50"
                r="42"
                fill="none"
                stroke="#f43f5e"
                strokeWidth="8"
                strokeLinecap="round"
                strokeDasharray={`${scorePercent * 2.64} ${264 - scorePercent * 2.64}`}
              />
            </svg>
            <span className="absolute text-3xl font-bold text-rose-600">{scorePercent}%</span>
          </div>
          <span className="text-sm text-gray-500">{t('compatibility_score')}</span>

          <div className="flex items-center gap-2">
            <span className={`rounded-full px-3 py-1 text-xs font-medium ${statusColor}`}>
              {t(match.status)}
            </span>
            {match.match_type === 'cold_start' && (
              <span className="rounded-full bg-purple-100 px-3 py-1 text-xs font-medium text-purple-600">
                {t('cold_start_match')}
              </span>
            )}
          </div>
        </div>
      </Card>

      {/* Signal summary */}
      <Card>
        <h2 className="mb-3 text-base font-semibold text-gray-900">{t('signal_summary')}</h2>

        {/* Shared tags */}
        {match.signal_summary.shared_tags.length > 0 && (
          <div className="mb-3">
            <h3 className="mb-1.5 text-sm font-medium text-gray-600">{t('shared_tags')}</h3>
            <div className="flex flex-wrap gap-1.5">
              {match.signal_summary.shared_tags.map((tag) => (
                <span key={tag} className="rounded-full bg-rose-50 px-2.5 py-1 text-xs text-rose-600">
                  {tag}
                </span>
              ))}
            </div>
          </div>
        )}

        {/* Strong ratings */}
        {match.signal_summary.strong_rating_count > 0 && (
          <div className="mb-3 flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-amber-400" viewBox="0 0 20 20" fill="currentColor">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
            <span className="text-sm text-gray-700">
              {t('strong_ratings')}: {match.signal_summary.strong_rating_count}
            </span>
          </div>
        )}

        {/* Matchmaker notes */}
        {match.signal_summary.top_matchmaker_notes.length > 0 && (
          <div>
            <h3 className="mb-1.5 text-sm font-medium text-gray-600">{t('matchmaker_notes')}</h3>
            <ul className="space-y-1.5">
              {match.signal_summary.top_matchmaker_notes.map((note, i) => (
                <li key={i} className="flex items-start gap-2 text-sm text-gray-600">
                  <span className="mt-0.5 h-1.5 w-1.5 shrink-0 rounded-full bg-rose-300" />
                  {note}
                </li>
              ))}
            </ul>
          </div>
        )}
      </Card>

      {/* Timeline */}
      <Card>
        <h2 className="mb-3 text-base font-semibold text-gray-900">{t('match_timeline')}</h2>
        <div className="space-y-3">
          <TimelineEntry
            label={t('created_at')}
            date={match.inserted_at}
            active
          />
          {match.status !== 'pending_intro' && (
            <TimelineEntry
              label={t(match.status)}
              date={match.updated_at}
              active={match.status === 'chatting' || match.status === 'introduced'}
            />
          )}
        </div>
      </Card>

      {/* Action buttons */}
      {isPending && (
        <div className="flex gap-3">
          <Button
            variant="outline"
            fullWidth
            onClick={() => handleRespond('declined')}
            isLoading={isResponding}
          >
            {t('decline_intro')}
          </Button>
          <Button
            fullWidth
            onClick={() => handleRespond('accepted')}
            isLoading={isResponding}
          >
            {t('accept_intro')}
          </Button>
        </div>
      )}

      {isChatting && (
        <Button fullWidth size="lg">
          {t('message_partner')}
        </Button>
      )}
    </div>
  );
}

function TimelineEntry({
  label,
  date,
  active,
}: {
  label: string;
  date: string;
  active: boolean;
}) {
  const formatted = new Date(date).toLocaleDateString('ja-JP', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <div className="flex items-center gap-3">
      <div
        className={`h-3 w-3 shrink-0 rounded-full ${
          active ? 'bg-rose-500' : 'bg-gray-300'
        }`}
      />
      <div className="flex-1">
        <p className="text-sm font-medium text-gray-700">{label}</p>
        <p className="text-xs text-gray-400">{formatted}</p>
      </div>
    </div>
  );
}
