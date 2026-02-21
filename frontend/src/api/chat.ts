import apiClient from './client';
import type { Conversation, ChatMessage } from '../types';

export const chatApi = {
  listConversations: (page = 1, limit = 20) =>
    apiClient.get<{ conversations: Conversation[] }>('/conversations', {
      params: { page, limit },
    }),

  getConversation: (id: string) =>
    apiClient.get<{ conversation: Conversation }>(`/conversations/${id}`),

  listMessages: (conversationId: string, before?: string, limit = 50) =>
    apiClient.get<{ messages: ChatMessage[] }>(
      `/conversations/${conversationId}/messages`,
      { params: { before, limit } },
    ),

  sendMessage: (
    conversationId: string,
    content: string,
    messageType = 'text',
  ) =>
    apiClient.post<{ message: ChatMessage }>(
      `/conversations/${conversationId}/messages`,
      { content, message_type: messageType },
    ),

  markRead: (conversationId: string) =>
    apiClient.post(`/conversations/${conversationId}/read`),

  getUnreadCount: () =>
    apiClient.get<{ unread_count: number }>('/chat/unread-count'),
};
