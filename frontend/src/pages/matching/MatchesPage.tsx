import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import { useMatchingStore } from '../../store/matching';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Avatar } from '../../components/ui/Avatar';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';
import type { Match } from '../../types';

type TabFilter = 'all' | 'pending_intro' | 'chatting' | 'ended';

const STATUS_COLORS: Record<string, string> = {
  pending_intro: 'bg-amber-100 text-amber-700',
  introduced: 'bg-blue-100 text-blue-700',
  chatting: 'bg-green-100 text-green-700',
  expired: 'bg-gray-100 text-gray-500',
  declined: 'bg-red-100 text-red-600',
};

function getTimeRemaining(expiresAt: string): string {
  const diff = new Date(expiresAt).getTime() - Date.now();
  if (diff <= 0) return '-';
  const hours = Math.floor(diff / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
  if (hours > 24) return `${Math.floor(hours / 24)}d`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

export function MatchesPage() {
  const { t } = useTranslation('matching');
  const navigate = useNavigate();
  const { matches, isLoading, fetchMatches, respondToMatch } = useMatchingStore();
  const [activeTab, setActiveTab] = useState<TabFilter>('all');

  useEffect(() => {
    fetchMatches();
  }, [fetchMatches]);

  const filteredMatches = matches.filter((m) => {
    if (activeTab === 'all') return true;
    if (activeTab === 'ended') return m.status === 'expired' || m.status === 'declined';
    return m.status === activeTab;
  });

  const handleRespond = async (matchId: string, response: 'accepted' | 'declined') => {
    try {
      await respondToMatch(matchId, response);
      toast(
        response === 'accepted' ? t('accept_intro') : t('decline_intro'),
        response === 'accepted' ? 'success' : 'info',
      );
    } catch {
      // error is handled by store
    }
  };

  const tabs: { key: TabFilter; label: string }[] = [
    { key: 'all', label: t('all') },
    { key: 'pending_intro', label: t('pending_intro') },
    { key: 'chatting', label: t('chatting') },
    { key: 'ended', label: t('ended') },
  ];

  if (isLoading && matches.length === 0) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-4">
      <h1 className="text-xl font-bold text-gray-900">{t('matches')}</h1>

      {/* Tab filters */}
      <div className="flex gap-2 overflow-x-auto scrollbar-hide">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setActiveTab(tab.key)}
            className={`shrink-0 rounded-full px-4 py-1.5 text-sm font-medium transition-colors ${
              activeTab === tab.key
                ? 'bg-rose-500 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Match list */}
      {filteredMatches.length === 0 ? (
        <Card>
          <p className="text-center text-gray-500">{t('no_matches')}</p>
        </Card>
      ) : (
        <div className="space-y-3">
          {filteredMatches.map((match) => (
            <MatchCard
              key={match.id}
              match={match}
              t={t}
              onRespond={handleRespond}
              onViewDetail={() => navigate(`/matches/${match.id}`)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function MatchCard({
  match,
  t,
  onRespond,
  onViewDetail,
}: {
  match: Match;
  t: (key: string, opts?: Record<string, unknown>) => string;
  onRespond: (matchId: string, response: 'accepted' | 'declined') => void;
  onViewDetail: () => void;
}) {
  const statusColor = STATUS_COLORS[match.status] || 'bg-gray-100 text-gray-500';
  const statusLabel = t(match.status);
  const isPending = match.status === 'pending_intro';

  return (
    <Card padding="sm" className="cursor-pointer transition-shadow hover:shadow-md" onClick={onViewDetail}>
      <div className="flex items-start gap-3">
        <Avatar name={match.person_b_id} size="lg" />

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${statusColor}`}>
              {statusLabel}
            </span>
            {match.match_type === 'cold_start' && (
              <span className="rounded-full bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-600">
                {t('cold_start_match')}
              </span>
            )}
          </div>

          {/* Compatibility score */}
          <div className="mt-1 flex items-center gap-2">
            <span className="text-sm font-semibold text-rose-600">
              {Math.round(match.compatibility_score * 100)}%
            </span>
            <span className="text-xs text-gray-400">{t('compatibility_score')}</span>
          </div>

          {/* Signal summary */}
          {match.signal_summary.shared_tags.length > 0 && (
            <div className="mt-1.5 flex flex-wrap gap-1">
              {match.signal_summary.shared_tags.slice(0, 3).map((tag) => (
                <span key={tag} className="rounded-full bg-rose-50 px-2 py-0.5 text-[11px] text-rose-500">
                  {tag}
                </span>
              ))}
              {match.signal_summary.strong_rating_count > 0 && (
                <span className="rounded-full bg-amber-50 px-2 py-0.5 text-[11px] text-amber-600">
                  {t('strong_ratings')}: {match.signal_summary.strong_rating_count}
                </span>
              )}
            </div>
          )}

          {/* Time remaining for pending intros */}
          {isPending && (
            <p className="mt-1 text-xs text-gray-400">
              {t('time_remaining')}: {getTimeRemaining(match.expires_at)}
            </p>
          )}
        </div>
      </div>

      {/* Accept/Decline buttons for pending intros */}
      {isPending && (
        <div className="mt-3 flex gap-2" onClick={(e) => e.stopPropagation()}>
          <Button
            size="sm"
            variant="outline"
            fullWidth
            onClick={() => onRespond(match.id, 'declined')}
          >
            {t('decline_intro')}
          </Button>
          <Button
            size="sm"
            fullWidth
            onClick={() => onRespond(match.id, 'accepted')}
          >
            {t('accept_intro')}
          </Button>
        </div>
      )}
    </Card>
  );
}
