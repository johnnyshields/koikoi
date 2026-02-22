import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useChatStore } from '../../store/chat';
import { useSocialStore } from '../../store/social';
import { useShokaiStore } from '../../store/shokai';
import { useAuth } from '../../hooks/useAuth';
import { Avatar } from '../../components/ui/Avatar';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import { Modal } from '../../components/ui/Modal';
import { GroupAvatar } from '../../components/chat/GroupAvatar';
import type { Connection } from '../../types';

function formatTime(dateStr: string): string {
  const date = new Date(dateStr);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) {
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  if (diffDays === 1) {
    return '昨日';
  }
  if (diffDays < 7) {
    return `${diffDays}日前`;
  }
  return date.toLocaleDateString();
}

function getFriendUserId(connection: Connection, currentUserId: string): string {
  return connection.requester_id === currentUserId
    ? connection.recipient_id
    : connection.requester_id;
}

export function ConversationsPage() {
  const { t } = useTranslation('chat');
  const { t: ts } = useTranslation('shokai');
  const navigate = useNavigate();
  const { user } = useAuth();
  const { conversations, isLoading, fetchConversations, createDm } = useChatStore();
  const { friends, fetchFriends } = useSocialStore();
  const { pending: pendingShokais, fetchPending: fetchPendingShokais } = useShokaiStore();
  const [showNewChat, setShowNewChat] = useState(false);
  const [showFabMenu, setShowFabMenu] = useState(false);

  useEffect(() => {
    fetchConversations();
    fetchPendingShokais();
  }, [fetchConversations, fetchPendingShokais]);

  const handleNewDm = () => {
    fetchFriends();
    setShowFabMenu(false);
    setShowNewChat(true);
  };

  const handleSelectFriend = async (friendUserId: string) => {
    const conv = await createDm(friendUserId);
    if (conv) {
      setShowNewChat(false);
      navigate(`/conversations/${conv.id}`);
    }
  };

  if (isLoading && conversations.length === 0) {
    return (
      <div className="flex items-center justify-center py-20">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  const sorted = [...conversations].sort((a, b) => {
    const aTime = a.last_message_at || a.inserted_at;
    const bTime = b.last_message_at || b.inserted_at;
    return new Date(bTime).getTime() - new Date(aTime).getTime();
  });

  return (
    <div className="space-y-1">
      <h2 className="mb-4 text-xl font-bold text-gray-900">
        {t('conversations')}
      </h2>

      {/* Pending shokais pinned at top */}
      {pendingShokais.length > 0 && (
        <div className="mb-3 space-y-2">
          {pendingShokais.map((shokai) => (
            <button
              key={shokai.id}
              type="button"
              className="flex w-full items-center gap-3 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-left transition-colors hover:bg-amber-100"
              onClick={() => navigate(`/shokai/${shokai.id}`)}
            >
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-amber-200 text-amber-700">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between">
                  <span className="truncate font-medium text-amber-900">
                    {ts('pending')}
                  </span>
                  <span className="ml-2 shrink-0 rounded-full bg-amber-200 px-2 py-0.5 text-xs font-medium text-amber-800">
                    {ts('title')}
                  </span>
                </div>
                <p className="truncate text-sm text-amber-700">
                  {shokai.matchmaker_note || ts('intro_message')}
                </p>
              </div>
            </button>
          ))}
        </div>
      )}

      {conversations.length === 0 && pendingShokais.length === 0 ? (
        <div className="py-20 text-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="mx-auto h-16 w-16 text-gray-300"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
            />
          </svg>
          <p className="mt-4 text-gray-500">{t('no_conversations')}</p>
        </div>
      ) : (
        <div className="divide-y divide-gray-100 overflow-hidden rounded-xl bg-white shadow-sm">
          {sorted.map((conversation) => {
            const otherUserId = conversation.participants.find(
              (id) => id !== user?.id,
            );
            const lastMsg = conversation.last_message;
            const hasUnread =
              lastMsg &&
              !lastMsg.read_at &&
              lastMsg.sender_id !== user?.id;

            const isGroup = conversation.type === 'group' || conversation.type === 'goukon';
            const displayName = isGroup
              ? conversation.name || '...'
              : otherUserId?.slice(-6) || '...';

            return (
              <button
                key={conversation.id}
                type="button"
                className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-gray-50"
                onClick={() => navigate(`/conversations/${conversation.id}`)}
              >
                {isGroup ? (
                  <GroupAvatar members={conversation.participants} size="lg" />
                ) : (
                  <Avatar name={otherUserId || '?'} size="lg" />
                )}
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-1.5">
                      <span className="truncate font-medium text-gray-900">
                        {displayName}
                      </span>
                      {conversation.type === 'goukon' && (
                        <span className="shrink-0 rounded bg-purple-100 px-1.5 py-0.5 text-[10px] font-medium text-purple-700">
                          合コン
                        </span>
                      )}
                      {conversation.type === 'shokai' && (
                        <span className="shrink-0 rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700">
                          紹介
                        </span>
                      )}
                    </div>
                    {conversation.last_message_at && (
                      <span className="ml-2 shrink-0 text-xs text-gray-400">
                        {formatTime(conversation.last_message_at)}
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-2">
                    <p className="truncate text-sm text-gray-500">
                      {lastMsg?.content || '...'}
                    </p>
                    {hasUnread && (
                      <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-rose-500" />
                    )}
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}

      {/* FAB */}
      <div className="fixed bottom-20 right-4 z-30">
        {showFabMenu && (
          <div className="mb-2 flex flex-col gap-2">
            <button
              type="button"
              onClick={handleNewDm}
              className="flex items-center gap-2 rounded-full bg-white px-4 py-2 text-sm font-medium text-gray-800 shadow-lg hover:bg-gray-50"
            >
              {t('new_chat')}
            </button>
            <button
              type="button"
              onClick={() => { setShowFabMenu(false); navigate('/conversations/new-group'); }}
              className="flex items-center gap-2 rounded-full bg-white px-4 py-2 text-sm font-medium text-gray-800 shadow-lg hover:bg-gray-50"
            >
              {t('new_group')}
            </button>
            <button
              type="button"
              onClick={() => { setShowFabMenu(false); navigate('/shokai/create'); }}
              className="flex items-center gap-2 rounded-full bg-white px-4 py-2 text-sm font-medium text-gray-800 shadow-lg hover:bg-gray-50"
            >
              {ts('create')}
            </button>
          </div>
        )}
        <button
          type="button"
          onClick={() => setShowFabMenu(!showFabMenu)}
          className="flex h-14 w-14 items-center justify-center rounded-full bg-rose-500 text-white shadow-lg hover:bg-rose-600"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className={`h-6 w-6 transition-transform ${showFabMenu ? 'rotate-45' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16m8-8H4" />
          </svg>
        </button>
      </div>

      {/* Backdrop for FAB menu */}
      {showFabMenu && (
        <div
          className="fixed inset-0 z-20"
          onClick={() => setShowFabMenu(false)}
        />
      )}

      {/* Friend picker modal */}
      <Modal isOpen={showNewChat} onClose={() => setShowNewChat(false)} title={t('new_chat')}>
        <div className="max-h-80 overflow-y-auto space-y-2">
          {friends.length === 0 ? (
            <p className="py-4 text-center text-sm text-gray-500">
              {t('no_conversations')}
            </p>
          ) : (
            friends.map((friend) => {
              const friendUserId = user ? getFriendUserId(friend, user.id) : friend.recipient_id;
              return (
                <button
                  key={friend.id}
                  type="button"
                  onClick={() => handleSelectFriend(friendUserId)}
                  className="w-full flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-gray-50"
                >
                  <Avatar name={friendUserId} size="md" />
                  <span className="text-sm font-medium text-gray-900">
                    {friendUserId.slice(-6)}
                  </span>
                </button>
              );
            })
          )}
        </div>
      </Modal>
    </div>
  );
}
