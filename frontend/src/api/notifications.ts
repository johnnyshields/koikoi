import apiClient from './client';
import type { Notification } from '../types';

export const notificationsApi = {
  list: (page = 1, limit = 20, unreadOnly = false) =>
    apiClient.get<{ notifications: Notification[] }>('/notifications', {
      params: { page, limit, unread_only: unreadOnly },
    }),

  markRead: (id: string) =>
    apiClient.post(`/notifications/${id}/read`),

  markAllRead: () =>
    apiClient.post('/notifications/read-all'),

  getUnreadCount: () =>
    apiClient.get<{ unread_count: number }>('/notifications/unread-count'),
};
