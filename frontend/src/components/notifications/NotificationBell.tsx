import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useNotificationStore } from '../../store/notifications';
import { useChannel } from '../../hooks/useChannel';
import { useAuth } from '../../hooks/useAuth';
import type { Notification } from '../../types';

export function NotificationBell() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { unreadCount, fetchUnreadCount, addNotification } =
    useNotificationStore();

  const channelTopic = user ? `notifications:${user.id}` : null;

  useChannel(channelTopic, {
    new_notification: (payload: unknown) => {
      addNotification(payload as Notification);
    },
  });

  useEffect(() => {
    fetchUnreadCount();
    const interval = setInterval(fetchUnreadCount, 60000);
    return () => clearInterval(interval);
  }, [fetchUnreadCount]);

  return (
    <button
      type="button"
      className="relative rounded-full p-2 text-gray-500 hover:bg-gray-100"
      aria-label="Notifications"
      onClick={() => navigate('/notifications')}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        className="h-6 w-6"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        strokeWidth={2}
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
        />
      </svg>
      {unreadCount > 0 && (
        <span className="absolute -top-0.5 -right-0.5 flex h-5 min-w-5 items-center justify-center rounded-full bg-red-500 px-1 text-xs font-bold text-white">
          {unreadCount > 99 ? '99+' : unreadCount}
        </span>
      )}
    </button>
  );
}
