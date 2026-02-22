import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useSocialStore } from '../../store/social';
import { useChatStore } from '../../store/chat';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Avatar } from '../../components/ui/Avatar';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { Modal } from '../../components/ui/Modal';
import { toast } from '../../components/ui/Toast';
import type { Connection } from '../../types';
import { useAuth } from '../../hooks/useAuth';

const TRUST_TIER_COLORS: Record<Connection['trust_tier'], string> = {
  inner_circle: 'bg-rose-100 text-rose-700',
  friends: 'bg-blue-100 text-blue-700',
  verified: 'bg-green-100 text-green-700',
  open: 'bg-gray-100 text-gray-700',
};

const TRUST_TIERS: Connection['trust_tier'][] = ['inner_circle', 'friends', 'verified', 'open'];

type Tab = 'friends' | 'matchmakers';

function getFriendUserId(connection: Connection, currentUserId: string): string {
  return connection.requester_id === currentUserId
    ? connection.recipient_id
    : connection.requester_id;
}

export function ContactsPage() {
  const { t } = useTranslation('social');
  const { t: tc } = useTranslation('common');
  const navigate = useNavigate();
  const { user } = useAuth();
  const {
    friends,
    pendingRequests,
    matchmakers,
    subjects,
    socialStatus,
    isLoading,
    fetchFriends,
    fetchPendingRequests,
    fetchMatchmakers,
    fetchSubjects,
    fetchSocialStatus,
    acceptFriendRequest,
    declineFriendRequest,
    removeFriend,
    updateTrustTier,
    removeMatchmaker,
    acceptMatchmakerInvite,
    declineMatchmakerInvite,
  } = useSocialStore();
  const { createDm } = useChatStore();

  const [activeTab, setActiveTab] = useState<Tab>('friends');
  const [searchQuery, setSearchQuery] = useState('');
  const [tierModalFriend, setTierModalFriend] = useState<Connection | null>(null);
  const [removeConfirmId, setRemoveConfirmId] = useState<string | null>(null);

  useEffect(() => {
    fetchFriends();
    fetchPendingRequests();
    fetchMatchmakers();
    fetchSubjects();
    fetchSocialStatus();
  }, [fetchFriends, fetchPendingRequests, fetchMatchmakers, fetchSubjects, fetchSocialStatus]);

  const filteredFriends = friends.filter((f) =>
    searchQuery ? f.id.includes(searchQuery) : true,
  );

  const handleAcceptFriend = async (id: string) => {
    try {
      await acceptFriendRequest(id);
      toast(t('pending.accept'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleDeclineFriend = async (id: string) => {
    try {
      await declineFriendRequest(id);
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleRemoveFriend = async (id: string) => {
    try {
      await removeFriend(id);
      setRemoveConfirmId(null);
      toast(t('friends.removeFriend'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleTierChange = async (id: string, tier: Connection['trust_tier']) => {
    try {
      await updateTrustTier(id, tier);
      setTierModalFriend(null);
      toast(t('trustTier.change'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleMessage = async (friendUserId: string) => {
    const conv = await createDm(friendUserId);
    if (conv) navigate(`/conversations/${conv.id}`);
  };

  const handleRemoveMatchmaker = async (id: string) => {
    try {
      await removeMatchmaker(id);
      toast(t('matchmakers.remove'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleAcceptMatchmaker = async (id: string) => {
    try {
      await acceptMatchmakerInvite(id);
      toast(t('matchmakers.accept'), 'success');
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  const handleDeclineMatchmaker = async (id: string) => {
    try {
      await declineMatchmakerInvite(id);
    } catch {
      toast(tc('errors.generic'), 'error');
    }
  };

  if (isLoading && friends.length === 0 && matchmakers.length === 0) {
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
      {/* Tab switcher */}
      <div className="flex rounded-lg bg-gray-100 p-1">
        <button
          type="button"
          onClick={() => setActiveTab('friends')}
          className={`flex-1 rounded-md py-2 text-sm font-medium transition-colors ${
            activeTab === 'friends'
              ? 'bg-white text-gray-900 shadow-sm'
              : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          {t('friends.title')}
        </button>
        <button
          type="button"
          onClick={() => setActiveTab('matchmakers')}
          className={`flex-1 rounded-md py-2 text-sm font-medium transition-colors ${
            activeTab === 'matchmakers'
              ? 'bg-white text-gray-900 shadow-sm'
              : 'text-gray-500 hover:text-gray-700'
          }`}
        >
          {t('matchmakers.title')}
        </button>
      </div>

      {activeTab === 'friends' && (
        <>
          {/* Pending requests */}
          {pendingRequests.length > 0 && (
            <Card>
              <h2 className="mb-3 text-base font-semibold text-gray-800">
                {t('pending.received')} ({pendingRequests.length})
              </h2>
              <div className="space-y-3">
                {pendingRequests.map((req) => (
                  <div key={req.id} className="flex items-center gap-3">
                    <Avatar name={req.requester_id} size="md" />
                    <div className="flex-1">
                      <p className="text-sm font-medium text-gray-900">
                        {req.requester_id}
                      </p>
                    </div>
                    <div className="flex gap-2">
                      <Button size="sm" onClick={() => handleAcceptFriend(req.id)}>
                        {t('pending.accept')}
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleDeclineFriend(req.id)}
                      >
                        {t('pending.decline')}
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </Card>
          )}

          {/* Search */}
          <div className="relative">
            <svg xmlns="http://www.w3.org/2000/svg" className="pointer-events-none absolute left-3 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={t('friends.search')}
              className="w-full rounded-lg border border-gray-300 bg-white py-2 pl-10 pr-3 text-base text-gray-900 placeholder:text-gray-400 focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20"
            />
          </div>

          {/* Friends count */}
          <p className="text-sm text-gray-500">
            {t('friends.count', { count: filteredFriends.length })}
          </p>

          {/* Friends list */}
          {filteredFriends.length === 0 ? (
            <Card>
              <p className="py-8 text-center text-gray-500">{t('friends.noFriends')}</p>
            </Card>
          ) : (
            <div className="space-y-2">
              {filteredFriends.map((friend) => {
                const friendUserId = user ? getFriendUserId(friend, user.id) : friend.recipient_id;
                return (
                  <Card key={friend.id} padding="sm">
                    <div className="flex items-center gap-3">
                      <button
                        type="button"
                        onClick={() => navigate(`/profile/${friendUserId}`)}
                        className="shrink-0"
                      >
                        <Avatar name={friendUserId} size="md" />
                      </button>
                      <div className="flex-1 min-w-0">
                        <button
                          type="button"
                          onClick={() => navigate(`/profile/${friendUserId}`)}
                          className="text-sm font-medium text-gray-900 hover:text-rose-600"
                        >
                          {friendUserId.slice(-6)}
                        </button>
                        <button
                          type="button"
                          onClick={() => setTierModalFriend(friend)}
                          className={`mt-0.5 block rounded-full px-2 py-0.5 text-xs font-medium ${TRUST_TIER_COLORS[friend.trust_tier]}`}
                        >
                          {t(`trustTier.${friend.trust_tier}`)}
                        </button>
                      </div>
                      <button
                        type="button"
                        onClick={() => handleMessage(friendUserId)}
                        className="rounded-full p-2 text-rose-500 hover:bg-rose-50"
                        title="Message"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                          <path strokeLinecap="round" strokeLinejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                        </svg>
                      </button>
                      <button
                        type="button"
                        onClick={() => setRemoveConfirmId(friend.id)}
                        className="rounded-full p-2 text-gray-400 hover:bg-gray-100 hover:text-red-500"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                          <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                        </svg>
                      </button>
                    </div>
                  </Card>
                );
              })}
            </div>
          )}

          {/* Trust tier modal */}
          <Modal
            isOpen={!!tierModalFriend}
            onClose={() => setTierModalFriend(null)}
            title={t('trustTier.change')}
          >
            <div className="space-y-2">
              {TRUST_TIERS.map((tier) => (
                <button
                  key={tier}
                  type="button"
                  onClick={() => tierModalFriend && handleTierChange(tierModalFriend.id, tier)}
                  className={`w-full rounded-lg px-4 py-3 text-left text-sm font-medium transition-colors ${
                    tierModalFriend?.trust_tier === tier
                      ? 'bg-rose-50 text-rose-700 ring-1 ring-rose-500'
                      : 'bg-gray-50 text-gray-700 hover:bg-gray-100'
                  }`}
                >
                  {t(`trustTier.${tier}`)}
                </button>
              ))}
            </div>
          </Modal>

          {/* Remove confirmation modal */}
          <Modal
            isOpen={!!removeConfirmId}
            onClose={() => setRemoveConfirmId(null)}
            title={t('friends.removeFriend')}
          >
            <p className="mb-4 text-sm text-gray-600">{t('friends.removeConfirm')}</p>
            <div className="flex gap-2">
              <Button
                variant="outline"
                fullWidth
                onClick={() => setRemoveConfirmId(null)}
              >
                {tc('actions.cancel')}
              </Button>
              <Button
                variant="danger"
                fullWidth
                onClick={() => removeConfirmId && handleRemoveFriend(removeConfirmId)}
              >
                {tc('actions.delete')}
              </Button>
            </div>
          </Modal>
        </>
      )}

      {activeTab === 'matchmakers' && (
        <>
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
                      <Button size="sm" onClick={() => handleAcceptMatchmaker(sub.id)}>
                        {t('matchmakers.accept')}
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => handleDeclineMatchmaker(sub.id)}
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
                        onClick={() => handleRemoveMatchmaker(mm.id)}
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
        </>
      )}
    </div>
  );
}
