import { create } from 'zustand';
import { notificationsApi } from '../api/notifications';
import type { Notification } from '../types';

interface NotificationState {
  notifications: Notification[];
  unreadCount: number;
  isLoading: boolean;
  error: string | null;

  fetchNotifications: (page?: number, unreadOnly?: boolean) => Promise<void>;
  markRead: (id: string) => Promise<void>;
  markAllRead: () => Promise<void>;
  fetchUnreadCount: () => Promise<void>;
  addNotification: (notification: Notification) => void;
  clearError: () => void;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  notifications: [],
  unreadCount: 0,
  isLoading: false,
  error: null,

  fetchNotifications: async (page = 1, unreadOnly = false) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await notificationsApi.list(page, 20, unreadOnly);
      set({
        notifications:
          page === 1
            ? data.notifications
            : [...get().notifications, ...data.notifications],
        isLoading: false,
      });
    } catch {
      set({ error: 'Failed to load notifications', isLoading: false });
    }
  },

  markRead: async (id) => {
    try {
      await notificationsApi.markRead(id);
      set({
        notifications: get().notifications.map((n) =>
          n.id === id ? { ...n, read: true } : n,
        ),
        unreadCount: Math.max(0, get().unreadCount - 1),
      });
    } catch {
      // silent fail
    }
  },

  markAllRead: async () => {
    try {
      await notificationsApi.markAllRead();
      set({
        notifications: get().notifications.map((n) => ({ ...n, read: true })),
        unreadCount: 0,
      });
    } catch {
      set({ error: 'Failed to mark all read' });
    }
  },

  fetchUnreadCount: async () => {
    try {
      const { data } = await notificationsApi.getUnreadCount();
      set({ unreadCount: data.unread_count });
    } catch {
      // silent fail
    }
  },

  addNotification: (notification) => {
    const exists = get().notifications.some((n) => n.id === notification.id);
    if (exists) return;
    set({
      notifications: [notification, ...get().notifications],
      unreadCount: get().unreadCount + 1,
    });
  },

  clearError: () => set({ error: null }),
}));
