import { useEffect, useRef, useState, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useChatStore } from '../../store/chat';
import { useAuth } from '../../hooks/useAuth';
import { useChannel } from '../../hooks/useChannel';
import { Avatar } from '../../components/ui/Avatar';
import { GroupAvatar } from '../../components/chat/GroupAvatar';
import { ShokaiCardBubble } from '../../components/chat/ShokaiCardBubble';
import { LoadingSpinner } from '../../components/ui/LoadingSpinner';
import type { ChatMessage } from '../../types';

function formatMessageDate(dateStr: string, t: (key: string) => string): string {
  const date = new Date(dateStr);
  const now = new Date();
  const isToday = date.toDateString() === now.toDateString();
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const isYesterday = date.toDateString() === yesterday.toDateString();

  if (isToday) return t('today');
  if (isYesterday) return t('yesterday');
  return date.toLocaleDateString();
}

function formatMessageTime(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
  });
}

function groupMessagesByDate(
  messages: ChatMessage[],
  t: (key: string) => string,
): { date: string; messages: ChatMessage[] }[] {
  const groups: { date: string; messages: ChatMessage[] }[] = [];
  let currentDate = '';

  for (const msg of messages) {
    const dateLabel = formatMessageDate(msg.inserted_at, t);
    if (dateLabel !== currentDate) {
      currentDate = dateLabel;
      groups.push({ date: dateLabel, messages: [] });
    }
    groups[groups.length - 1].messages.push(msg);
  }

  return groups;
}

export function ChatPage() {
  const { conversationId } = useParams<{ conversationId: string }>();
  const navigate = useNavigate();
  const { t } = useTranslation('chat');
  const { user } = useAuth();
  const {
    messages,
    currentConversation,
    isLoading,
    fetchMessages,
    addMessage,
    markRead,
    setCurrentConversation,
    fetchConversations,
    conversations,
  } = useChatStore();

  const [inputText, setInputText] = useState('');
  const [typingUsers, setTypingUsers] = useState<string[]>([]);
  const [hasMore, setHasMore] = useState(true);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);
  const typingTimeoutRef = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  const conversationMessages = conversationId
    ? messages[conversationId] || []
    : [];

  const isGroup =
    currentConversation?.type === 'group' || currentConversation?.type === 'goukon';

  const otherUserId = !isGroup
    ? currentConversation?.participants.find((id) => id !== user?.id)
    : undefined;

  const displayName = isGroup
    ? currentConversation?.name || '...'
    : otherUserId?.slice(-6) || '...';

  const memberCount = currentConversation?.participants.length || 0;

  const isFreeMan =
    user?.gender === 'male' && user?.subscription?.plan === 'free';

  // Channel for real-time messaging
  const channelTopic = conversationId ? `chat:${conversationId}` : null;

  const handleNewMessage = useCallback(
    (payload: unknown) => {
      const msg = payload as ChatMessage;
      addMessage(msg);
    },
    [addMessage],
  );

  const handleTyping = useCallback(
    (payload: unknown) => {
      const data = payload as { user_id: string };
      if (data.user_id !== user?.id) {
        setTypingUsers((prev) => {
          if (!prev.includes(data.user_id)) return [...prev, data.user_id];
          return prev;
        });
        // Clear typing after 3s
        if (typingTimeoutRef.current[data.user_id]) {
          clearTimeout(typingTimeoutRef.current[data.user_id]);
        }
        typingTimeoutRef.current[data.user_id] = setTimeout(() => {
          setTypingUsers((prev) => prev.filter((id) => id !== data.user_id));
        }, 3000);
      }
    },
    [user?.id],
  );

  const handleMessagesRead = useCallback(() => {
    // Could update read receipts here
  }, []);

  const { push } = useChannel(channelTopic, {
    new_message: handleNewMessage,
    typing: handleTyping,
    messages_read: handleMessagesRead,
  });

  // Load conversation and messages
  useEffect(() => {
    if (!conversationId) return;

    if (conversations.length === 0) {
      fetchConversations();
    }

    fetchMessages(conversationId).then(() => {
      markRead(conversationId);
    });

    return () => {
      setCurrentConversation(null);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [conversationId]);

  // Set current conversation from list
  useEffect(() => {
    if (conversationId && conversations.length > 0) {
      const conv = conversations.find((c) => c.id === conversationId);
      if (conv) setCurrentConversation(conv);
    }
  }, [conversationId, conversations, setCurrentConversation]);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [conversationMessages.length]);

  const handleSend = () => {
    const text = inputText.trim();
    if (!text || !conversationId || isFreeMan) return;

    push('new_message', { content: text, message_type: 'text' });
    setInputText('');
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setInputText(e.target.value);
    push('typing', {});
  };

  const handleLoadMore = () => {
    if (!conversationId || conversationMessages.length === 0) return;
    const oldestMessage = conversationMessages[0];
    fetchMessages(conversationId, oldestMessage.id).then(() => {
      const newMessages = useChatStore.getState().messages[conversationId] || [];
      if (newMessages.length === conversationMessages.length) {
        setHasMore(false);
      }
    });
  };

  const dateGroups = groupMessagesByDate(conversationMessages, t);

  return (
    <div className="flex h-[calc(100vh-8rem)] flex-col">
      {/* Header */}
      <div className="flex items-center gap-3 border-b border-gray-200 bg-white px-4 py-3">
        <button
          type="button"
          onClick={() => navigate('/')}
          className="rounded-full p-1 text-gray-500 hover:bg-gray-100"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            className="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={2}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M15 19l-7-7 7-7"
            />
          </svg>
        </button>
        {isGroup ? (
          <GroupAvatar members={currentConversation?.participants} size="md" />
        ) : (
          <Avatar name={otherUserId || '?'} size="md" />
        )}
        <button
          type="button"
          className="min-w-0 flex-1 text-left"
          onClick={() => {
            if (isGroup && conversationId) {
              navigate(`/conversations/${conversationId}/settings`);
            }
          }}
          disabled={!isGroup}
        >
          <p className="truncate font-medium text-gray-900">{displayName}</p>
          {isGroup && (
            <p className="text-xs text-gray-500">
              {t('member_count', { count: memberCount })}
            </p>
          )}
          {typingUsers.length > 0 && (
            <p className="text-xs text-rose-500">{t('typing')}</p>
          )}
        </button>
        {isGroup && (
          <button
            type="button"
            onClick={() => navigate(`/conversations/${conversationId}/settings`)}
            className="rounded-full p-1.5 text-gray-500 hover:bg-gray-100"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </button>
        )}
      </div>

      {/* Messages */}
      <div
        ref={messagesContainerRef}
        className="flex-1 overflow-y-auto bg-gray-50 px-4 py-3"
      >
        {isLoading && conversationMessages.length === 0 ? (
          <div className="flex items-center justify-center py-20">
            <LoadingSpinner size="lg" />
          </div>
        ) : (
          <>
            {hasMore && conversationMessages.length > 0 && (
              <button
                type="button"
                onClick={handleLoadMore}
                className="mx-auto mb-4 block rounded-full bg-gray-200 px-4 py-1.5 text-xs text-gray-600 hover:bg-gray-300"
              >
                {t('load_more')}
              </button>
            )}
            {dateGroups.map((group) => (
              <div key={group.date}>
                <div className="my-4 flex items-center justify-center">
                  <span className="rounded-full bg-gray-200 px-3 py-1 text-xs text-gray-500">
                    {group.date}
                  </span>
                </div>
                {group.messages.map((msg) => {
                  // System messages
                  if (msg.message_type === 'system') {
                    return (
                      <div key={msg.id} className="my-2 text-center">
                        <span className="inline-block rounded-full bg-gray-100 px-3 py-1 text-xs text-gray-500">
                          {msg.content}
                        </span>
                      </div>
                    );
                  }

                  // Shokai card messages
                  if (msg.message_type === 'shokai_card') {
                    return <ShokaiCardBubble key={msg.id} message={msg} />;
                  }

                  const isMine = msg.sender_id === user?.id;
                  return (
                    <div
                      key={msg.id}
                      className={`mb-2 flex ${isMine ? 'justify-end' : 'justify-start'}`}
                    >
                      {!isMine && isGroup && (
                        <div className="mr-2 shrink-0 self-end">
                          <Avatar name={msg.sender_id || '?'} size="sm" />
                        </div>
                      )}
                      <div className="max-w-[75%]">
                        {!isMine && isGroup && msg.sender_id && (
                          <p className="mb-0.5 text-[10px] text-gray-500 ml-1">
                            {msg.sender_id.slice(-6)}
                          </p>
                        )}
                        <div
                          className={`rounded-2xl px-4 py-2.5 ${
                            isMine
                              ? 'rounded-br-md bg-rose-500 text-white'
                              : 'rounded-bl-md bg-white text-gray-900 shadow-sm'
                          }`}
                        >
                          <p className="whitespace-pre-wrap break-words text-sm">
                            {msg.content}
                          </p>
                          <div
                            className={`mt-1 flex items-center gap-1 text-xs ${
                              isMine ? 'justify-end text-rose-200' : 'text-gray-400'
                            }`}
                          >
                            <span>{formatMessageTime(msg.inserted_at)}</span>
                            {isMine && msg.read_at && (
                              <span>{t('read')}</span>
                            )}
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ))}
            <div ref={messagesEndRef} />
          </>
        )}
      </div>

      {/* Input bar or paywall */}
      {isFreeMan ? (
        <div className="border-t border-gray-200 bg-white px-4 py-4">
          <div className="rounded-xl bg-gray-50 p-4 text-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              className="mx-auto mb-2 h-8 w-8 text-gray-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={1.5}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
              />
            </svg>
            <p className="mb-3 text-sm text-gray-600">
              {t('subscription_required')}
            </p>
            <button
              type="button"
              className="rounded-lg bg-rose-500 px-6 py-2 text-sm font-medium text-white hover:bg-rose-600"
            >
              {t('view_plans')}
            </button>
          </div>
        </div>
      ) : (
        <div className="border-t border-gray-200 bg-white px-4 py-3">
          <div className="flex items-center gap-2">
            <input
              type="text"
              value={inputText}
              onChange={handleInputChange}
              onKeyDown={handleKeyDown}
              placeholder={t('type_message')}
              className="flex-1 rounded-full border border-gray-300 px-4 py-2.5 text-sm outline-none transition-colors focus:border-rose-400 focus:ring-2 focus:ring-rose-100"
            />
            <button
              type="button"
              onClick={handleSend}
              disabled={!inputText.trim()}
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-rose-500 text-white transition-colors hover:bg-rose-600 disabled:opacity-40"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                className="h-5 w-5"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M3.478 2.405a.75.75 0 00-.926.94l2.432 7.905H13.5a.75.75 0 010 1.5H4.984l-2.432 7.905a.75.75 0 00.926.94 60.519 60.519 0 0018.445-8.986.75.75 0 000-1.218A60.517 60.517 0 003.478 2.405z" />
              </svg>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
