import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useChatStore } from '../../store/chat';
import { useAuth } from '../../hooks/useAuth';
import { Avatar } from '../../components/ui/Avatar';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';

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

export function ConversationsPage() {
  const { t } = useTranslation('chat');
  const navigate = useNavigate();
  const { user } = useAuth();
  const { conversations, isLoading, fetchConversations } = useChatStore();

  useEffect(() => {
    fetchConversations();
  }, [fetchConversations]);

  if (isLoading && conversations.length === 0) {
    return (
      <div className="flex items-center justify-center py-20">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  if (conversations.length === 0) {
    return (
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

          return (
            <button
              key={conversation.id}
              type="button"
              className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-gray-50"
              onClick={() => navigate(`/conversations/${conversation.id}`)}
            >
              <Avatar name={otherUserId || '?'} size="lg" />
              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between">
                  <span className="truncate font-medium text-gray-900">
                    {otherUserId?.slice(-6) || '...'}
                  </span>
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
    </div>
  );
}
