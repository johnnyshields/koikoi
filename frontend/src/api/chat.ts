import apiClient from './client';
import type { Conversation, ChatMessage, MemberInfo } from '../types';

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

  createDm: (friendId: string) =>
    apiClient.post<{ conversation: Conversation }>('/conversations/dm', {
      friend_id: friendId,
    }),

  createGroup: (name: string, memberIds: string[]) =>
    apiClient.post<{ conversation: Conversation }>('/conversations/group', {
      name,
      member_ids: memberIds,
    }),

  createGoukon: (name: string, memberIds: string[], expiresInHours: number) =>
    apiClient.post<{ conversation: Conversation }>('/conversations/goukon', {
      name,
      member_ids: memberIds,
      expires_in_hours: expiresInHours,
    }),

  addMembers: (conversationId: string, memberIds: string[]) =>
    apiClient.post<{ status: string; added: number }>(
      `/conversations/${conversationId}/members`,
      { member_ids: memberIds },
    ),

  removeMember: (conversationId: string, userId: string) =>
    apiClient.delete(`/conversations/${conversationId}/members/${userId}`),

  leaveGroup: (conversationId: string) =>
    apiClient.post(`/conversations/${conversationId}/leave`),

  updateGroup: (conversationId: string, attrs: { name?: string }) =>
    apiClient.put<{ conversation: Conversation }>(
      `/conversations/${conversationId}`,
      attrs,
    ),

  listMembers: (conversationId: string) =>
    apiClient.get<{ members: MemberInfo[] }>(
      `/conversations/${conversationId}/members`,
    ),
};
