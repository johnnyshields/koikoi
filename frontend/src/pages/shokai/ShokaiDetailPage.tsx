import { useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useShokaiStore } from '../../store/shokai';
import { useAuth } from '../../hooks/useAuth';
import { Avatar } from '../../components/ui/Avatar';
import { Button } from '../../components/ui/Button';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { toast } from '../../components/ui/Toast';
import type { ShokaiCard } from '../../types';

function StatusBadge({ status }: { status: ShokaiCard['status'] }) {
  const { t } = useTranslation('shokai');
  const colors: Record<ShokaiCard['status'], string> = {
    pending: 'bg-amber-100 text-amber-700',
    accepted: 'bg-green-100 text-green-700',
    declined: 'bg-red-100 text-red-700',
    expired: 'bg-gray-100 text-gray-500',
  };
  return (
    <span className={`inline-block rounded-full px-3 py-1 text-xs font-medium ${colors[status]}`}>
      {t(status)}
    </span>
  );
}

export function ShokaiDetailPage() {
  const { shokaiId } = useParams<{ shokaiId: string }>();
  const navigate = useNavigate();
  const { t } = useTranslation('shokai');
  const { t: tc } = useTranslation('common');
  const { user } = useAuth();
  const { pending, sent, respondToShokai, fetchPending, fetchSent, isLoading } = useShokaiStore();

  useEffect(() => {
    fetchPending();
    fetchSent();
  }, [fetchPending, fetchSent]);

  const shokai = [...pending, ...sent].find((s) => s.id === shokaiId);

  const isParty =
    shokai && user && (shokai.person_a_id === user.id || shokai.person_b_id === user.id);
  const isPending = shokai?.status === 'pending';

  const handleRespond = async (response: 'accepted' | 'declined') => {
    if (!shokaiId) return;
    const result = await respondToShokai(shokaiId, response);
    if (result) {
      toast(t('respond_success'), 'success');
      if (result.conversationId) {
        navigate(`/conversations/${result.conversationId}`);
      }
    } else {
      toast(tc('errors.generic'), 'error');
    }
  };

  if (isLoading && !shokai) {
    return (
      <div className="flex items-center justify-center py-20">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (!shokai) {
    return (
      <div className="py-20 text-center">
        <p className="text-gray-500">{tc('errors.notFound')}</p>
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-4">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => navigate(-1)}
          className="rounded-full p-1 text-gray-500 hover:bg-gray-100"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>
        <h1 className="text-xl font-bold text-gray-900">{t('title')}</h1>
      </div>

      {/* Status */}
      <div className="text-center">
        <StatusBadge status={shokai.status} />
      </div>

      {/* Profiles side by side */}
      <div className="rounded-xl bg-white p-6 shadow-sm">
        <div className="flex items-start justify-center gap-6">
          <div className="flex flex-col items-center text-center">
            <Avatar
              name={shokai.person_a_profile?.nickname || shokai.person_a_id}
              src={shokai.person_a_profile?.primary_photo?.thumbnail_url}
              size="xl"
            />
            <p className="mt-2 text-sm font-medium text-gray-900">
              {shokai.person_a_profile?.nickname || shokai.person_a_id.slice(-6)}
            </p>
            {shokai.person_a_profile?.age && (
              <p className="text-xs text-gray-500">
                {shokai.person_a_profile.age}{shokai.person_a_profile.prefecture ? ` / ${shokai.person_a_profile.prefecture}` : ''}
              </p>
            )}
            <span className={`mt-1 rounded-full px-2 py-0.5 text-[10px] font-medium ${
              shokai.person_a_response === 'accepted' ? 'bg-green-100 text-green-700' :
              shokai.person_a_response === 'declined' ? 'bg-red-100 text-red-700' :
              'bg-gray-100 text-gray-500'
            }`}>
              {t(shokai.person_a_response)}
            </span>
          </div>

          <div className="flex items-center pt-8">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-rose-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
            </svg>
          </div>

          <div className="flex flex-col items-center text-center">
            <Avatar
              name={shokai.person_b_profile?.nickname || shokai.person_b_id}
              src={shokai.person_b_profile?.primary_photo?.thumbnail_url}
              size="xl"
            />
            <p className="mt-2 text-sm font-medium text-gray-900">
              {shokai.person_b_profile?.nickname || shokai.person_b_id.slice(-6)}
            </p>
            {shokai.person_b_profile?.age && (
              <p className="text-xs text-gray-500">
                {shokai.person_b_profile.age}{shokai.person_b_profile.prefecture ? ` / ${shokai.person_b_profile.prefecture}` : ''}
              </p>
            )}
            <span className={`mt-1 rounded-full px-2 py-0.5 text-[10px] font-medium ${
              shokai.person_b_response === 'accepted' ? 'bg-green-100 text-green-700' :
              shokai.person_b_response === 'declined' ? 'bg-red-100 text-red-700' :
              'bg-gray-100 text-gray-500'
            }`}>
              {t(shokai.person_b_response)}
            </span>
          </div>
        </div>
      </div>

      {/* Matchmaker */}
      <div className="rounded-xl bg-white p-4 shadow-sm">
        <p className="mb-2 text-xs font-medium text-gray-500">{t('matchmaker')}</p>
        <div className="flex items-center gap-3">
          <Avatar
            name={shokai.matchmaker_profile?.nickname || shokai.matchmaker_id}
            src={shokai.matchmaker_profile?.primary_photo?.thumbnail_url}
            size="md"
          />
          <span className="text-sm font-medium text-gray-900">
            {shokai.matchmaker_profile?.nickname || shokai.matchmaker_id.slice(-6)}
          </span>
        </div>
      </div>

      {/* Matchmaker note */}
      {shokai.matchmaker_note && (
        <div className="rounded-xl bg-gray-50 p-4">
          <p className="text-sm text-gray-700 italic">
            &ldquo;{shokai.matchmaker_note}&rdquo;
          </p>
        </div>
      )}

      {/* Shared tags */}
      {shokai.compatibility_hints.shared_tags.length > 0 && (
        <div className="rounded-xl bg-white p-4 shadow-sm">
          <p className="mb-2 text-xs font-medium text-gray-500">{t('shared_tags')}</p>
          <div className="flex flex-wrap gap-2">
            {shokai.compatibility_hints.shared_tags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-rose-50 px-3 py-1 text-xs font-medium text-rose-600"
              >
                {tag}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Expiry */}
      <p className="text-center text-xs text-gray-400">
        {t('expires_at', { date: new Date(shokai.expires_at).toLocaleDateString() })}
      </p>

      {/* Actions */}
      {isPending && isParty && (
        <div className="flex gap-3">
          <Button fullWidth onClick={() => handleRespond('accepted')}>
            {t('accept')}
          </Button>
          <Button variant="outline" fullWidth onClick={() => handleRespond('declined')}>
            {t('decline')}
          </Button>
        </div>
      )}

      {/* Accepted — link to conversation */}
      {shokai.status === 'accepted' && shokai.result_conversation_id && (
        <div className="text-center">
          <p className="mb-2 text-sm font-medium text-green-600">{t('both_accepted')}</p>
          <Button onClick={() => navigate(`/conversations/${shokai.result_conversation_id}`)}>
            {tc('nav.chats', { defaultValue: 'Chat' })}
          </Button>
        </div>
      )}
    </div>
  );
}
