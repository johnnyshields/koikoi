import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useSocialStore } from '../../store/social';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Avatar } from '../../components/ui/Avatar';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';

export function MatchmakersPage() {
  const { t } = useTranslation('social');
  const { t: tc } = useTranslation('common');
  const {
    matchmakers,
    subjects,
    socialStatus,
    isLoading,
    fetchMatchmakers,
    fetchSubjects,
    fetchSocialStatus,
    removeMatchmaker,
    acceptMatchmakerInvite,
    declineMatchmakerInvite,
  } = useSocialStore();

  useEffect(() => {
    fetchMatchmakers();
    fetchSubjects();
    fetchSocialStatus();
  }, [fetchMatchmakers, fetchSubjects, fetchSocialStatus]);

  const handleRemove = async (id: string) => {
    try {
      await removeMatchmaker(id);
      toast(t('matchmakers.remove'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleAccept = async (id: string) => {
    try {
      await acceptMatchmakerInvite(id);
      toast(t('matchmakers.accept'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleDecline = async (id: string) => {
    try {
      await declineMatchmakerInvite(id);
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  if (isLoading && matchmakers.length === 0) {
    return (
      <div className="flex items-center justify-center py-12">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  const pendingSubjects = subjects.filter((s) => s.status === 'pending');
  const acceptedMatchmakers = matchmakers.filter((m) => m.status === 'accepted');
  const acceptedSubjects = subjects.filter((s) => s.status === 'accepted');

  return (
    <div className="space-y-4 pb-4">
      <h1 className="text-xl font-bold text-gray-900">{t('matchmakers.title')}</h1>

      {/* Status card */}
      {socialStatus && (
        <Card>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-700">{t('matchmakers.status')}</p>
              <p className={`text-xs ${socialStatus.matchmaking_active ? 'text-green-600' : 'text-gray-500'}`}>
                {socialStatus.matchmaking_active ? t('matchmakers.active') : t('matchmakers.inactive')}
              </p>
            </div>
            <div className="text-right text-xs text-gray-500">
              <p>{t('matchmakers.current', { count: socialStatus.matchmaker_count })}</p>
              <p>{t('matchmakers.required', { count: socialStatus.matchmakers_required })}</p>
            </div>
          </div>
        </Card>
      )}

      {/* Pending invites to be a matchmaker */}
      {pendingSubjects.length > 0 && (
        <Card>
          <h2 className="mb-3 text-base font-semibold text-gray-800">
            {t('matchmakers.invite')} ({pendingSubjects.length})
          </h2>
          <div className="space-y-3">
            {pendingSubjects.map((sub) => (
              <div key={sub.id} className="flex items-center gap-3">
                <Avatar name={sub.subject_id || sub.requester_id} size="md" />
                <div className="flex-1">
                  <p className="text-sm font-medium text-gray-900">
                    {sub.requester_id}
                  </p>
                </div>
                <div className="flex gap-2">
                  <Button size="sm" onClick={() => handleAccept(sub.id)}>
                    {t('matchmakers.accept')}
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleDecline(sub.id)}
                  >
                    {t('matchmakers.decline')}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* My matchmakers */}
      <div>
        <h2 className="mb-2 text-base font-semibold text-gray-800">
          {t('matchmakers.myMatchmakers')}
        </h2>
        {acceptedMatchmakers.length === 0 ? (
          <Card>
            <p className="py-4 text-center text-sm text-gray-500">
              {t('matchmakers.noMatchmakers')}
            </p>
          </Card>
        ) : (
          <div className="space-y-2">
            {acceptedMatchmakers.map((mm) => (
              <Card key={mm.id} padding="sm">
                <div className="flex items-center gap-3">
                  <Avatar name={mm.recipient_id} size="md" />
                  <div className="flex-1">
                    <p className="text-sm font-medium text-gray-900">
                      {mm.recipient_id}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleRemove(mm.id)}
                    className="rounded-full p-2 text-gray-400 hover:bg-gray-100 hover:text-red-500"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                      <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                    </svg>
                  </button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>

      {/* People I'm matchmaking for */}
      <div>
        <h2 className="mb-2 text-base font-semibold text-gray-800">
          {t('matchmakers.mySubjects')}
        </h2>
        {acceptedSubjects.length === 0 ? (
          <Card>
            <p className="py-4 text-center text-sm text-gray-500">
              {t('matchmakers.noSubjects')}
            </p>
          </Card>
        ) : (
          <div className="space-y-2">
            {acceptedSubjects.map((sub) => (
              <Card key={sub.id} padding="sm">
                <div className="flex items-center gap-3">
                  <Avatar name={sub.requester_id} size="md" />
                  <div className="flex-1">
                    <p className="text-sm font-medium text-gray-900">
                      {sub.requester_id}
                    </p>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
