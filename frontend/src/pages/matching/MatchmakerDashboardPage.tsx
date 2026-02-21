import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useMatchingStore } from '../../store/matching';
import { Card } from '../../components/ui/Card';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';

export function MatchmakerDashboardPage() {
  const { t } = useTranslation('matching');
  const { stats, fetchStats } = useMatchingStore();

  useEffect(() => {
    fetchStats();
  }, [fetchStats]);

  if (!stats) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  const achievements = getAchievements(stats.successful_matches, stats.total_ratings);

  return (
    <div className="space-y-4 pb-4">
      <h1 className="text-xl font-bold text-gray-900">{t('matchmaker_dashboard')}</h1>

      {/* Stats grid */}
      <div className="grid grid-cols-2 gap-3">
        <StatCard
          label={t('total_ratings')}
          value={stats.total_ratings}
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-amber-400" viewBox="0 0 20 20" fill="currentColor">
              <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
            </svg>
          }
        />
        <StatCard
          label={t('successful_matches')}
          value={stats.successful_matches}
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-rose-400" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clipRule="evenodd" />
            </svg>
          }
          highlight
        />
        <StatCard
          label={t('average_rating')}
          value={stats.average_rating.toFixed(1)}
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-blue-400" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clipRule="evenodd" />
            </svg>
          }
        />
        <StatCard
          label={t('pairs_skipped')}
          value={stats.pairs_skipped}
          icon={
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-gray-400" viewBox="0 0 20 20" fill="currentColor">
              <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
          }
        />
      </div>

      {/* Achievements */}
      {achievements.length > 0 && (
        <Card>
          <h2 className="mb-3 text-base font-semibold text-gray-900">{t('achievements')}</h2>
          <div className="space-y-2">
            {achievements.map((achievement) => (
              <div
                key={achievement.key}
                className="flex items-center gap-3 rounded-lg bg-gradient-to-r from-amber-50 to-rose-50 p-3"
              >
                <span className="text-2xl">{achievement.emoji}</span>
                <div>
                  <p className="text-sm font-semibold text-gray-800">{achievement.label}</p>
                  <p className="text-xs text-gray-500">{achievement.description}</p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Session summary */}
      <Card>
        <h2 className="mb-3 text-base font-semibold text-gray-900">{t('recent_activity')}</h2>
        <div className="flex items-center justify-between border-b border-gray-100 py-2 last:border-0">
          <span className="text-sm text-gray-600">{t('total_sessions')}</span>
          <span className="text-sm font-semibold text-gray-900">{stats.total_sessions}</span>
        </div>
        <div className="flex items-center justify-between py-2">
          <span className="text-sm text-gray-600">{t('total_ratings')}</span>
          <span className="text-sm font-semibold text-gray-900">{stats.total_ratings}</span>
        </div>
      </Card>
    </div>
  );
}

function StatCard({
  label,
  value,
  icon,
  highlight,
}: {
  label: string;
  value: string | number;
  icon: React.ReactNode;
  highlight?: boolean;
}) {
  return (
    <Card padding="sm">
      <div className="flex items-start gap-3">
        <div className={`rounded-lg p-2 ${highlight ? 'bg-rose-50' : 'bg-gray-50'}`}>
          {icon}
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-2xl font-bold text-gray-900">{value}</p>
          <p className="truncate text-xs text-gray-500">{label}</p>
        </div>
      </div>
    </Card>
  );
}

function getAchievements(
  successfulMatches: number,
  totalRatings: number,
): { key: string; emoji: string; label: string; description: string }[] {
  const achievements: { key: string; emoji: string; label: string; description: string }[] = [];

  if (successfulMatches >= 1) {
    achievements.push({
      key: 'first_match',
      emoji: '\u{1F389}',
      label: '\u521D\u3081\u3066\u306E\u30DE\u30C3\u30C1\uFF01',
      description: '\u6700\u521D\u306E\u30DE\u30C3\u30C1\u3092\u6210\u7ACB\u3055\u305B\u307E\u3057\u305F',
    });
  }
  if (totalRatings >= 10) {
    achievements.push({
      key: 'ten_ratings',
      emoji: '\u{1F31F}',
      label: '10\u56DE\u8A55\u4FA1\u9054\u6210',
      description: '10\u4EF6\u306E\u30DA\u30A2\u3092\u8A55\u4FA1\u3057\u307E\u3057\u305F',
    });
  }
  if (totalRatings >= 50) {
    achievements.push({
      key: 'fifty_ratings',
      emoji: '\u{1F4AB}',
      label: '50\u56DE\u8A55\u4FA1\u9054\u6210',
      description: '50\u4EF6\u306E\u30DA\u30A2\u3092\u8A55\u4FA1\u3057\u307E\u3057\u305F',
    });
  }
  if (totalRatings >= 100) {
    achievements.push({
      key: 'hundred_ratings',
      emoji: '\u{1F3C6}',
      label: '100\u56DE\u8A55\u4FA1\u9054\u6210\uFF01',
      description: '100\u4EF6\u306E\u30DA\u30A2\u3092\u8A55\u4FA1\u3057\u307E\u3057\u305F',
    });
  }
  if (successfulMatches >= 5) {
    achievements.push({
      key: 'five_matches',
      emoji: '\u{1F48C}',
      label: '5\u30DE\u30C3\u30C1\u9054\u6210',
      description: '5\u7D44\u306E\u30AB\u30C3\u30D7\u30EB\u3092\u8A95\u751F\u3055\u305B\u307E\u3057\u305F',
    });
  }

  return achievements;
}
