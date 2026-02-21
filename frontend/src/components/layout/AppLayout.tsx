import { Outlet, NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { NotificationBell } from '../notifications/NotificationBell';
import { useChatStore } from '../../store/chat';
import { useEffect } from 'react';

function NavIcon({
  label,
  path,
  badge,
  children,
}: {
  label: string;
  path: string;
  badge?: number;
  children: React.ReactNode;
}) {
  return (
    <NavLink
      to={path}
      className={({ isActive }) =>
        `relative flex flex-col items-center gap-1 px-3 py-2 text-xs transition-colors ${
          isActive ? 'text-rose-600' : 'text-gray-500 hover:text-gray-700'
        }`
      }
    >
      <div className="relative">
        {children}
        {badge != null && badge > 0 && (
          <span className="absolute -top-1.5 -right-2.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-0.5 text-[10px] font-bold text-white">
            {badge > 99 ? '99+' : badge}
          </span>
        )}
      </div>
      <span>{label}</span>
    </NavLink>
  );
}

export function AppLayout() {
  const { t } = useTranslation();
  const chatUnreadCount = useChatStore((s) => s.unreadCount);
  const fetchChatUnreadCount = useChatStore((s) => s.fetchUnreadCount);

  useEffect(() => {
    fetchChatUnreadCount();
    const interval = setInterval(fetchChatUnreadCount, 60000);
    return () => clearInterval(interval);
  }, [fetchChatUnreadCount]);

  return (
    <div className="flex min-h-screen flex-col bg-gray-50">
      {/* Top header */}
      <header className="sticky top-0 z-40 border-b border-gray-200 bg-white px-4 py-3">
        <div className="mx-auto flex max-w-lg items-center justify-between">
          <h1 className="text-xl font-bold text-rose-600">{t('appName')}</h1>
          <NotificationBell />
        </div>
      </header>

      {/* Page content */}
      <main className="mx-auto w-full max-w-lg flex-1 p-4">
        <Outlet />
      </main>

      {/* Bottom navigation */}
      <nav className="sticky bottom-0 z-40 border-t border-gray-200 bg-white">
        <div className="mx-auto flex max-w-lg justify-around">
          <NavIcon label={t('nav.home')} path="/">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
          </NavIcon>
          <NavIcon label={t('nav.matching')} path="/matching">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <rect x="2" y="3" width="8" height="11" rx="1.5" />
              <rect x="14" y="3" width="8" height="11" rx="1.5" />
              <path strokeLinecap="round" strokeLinejoin="round" d="M8.5 17.5l1.5 1.5 2-2 2 2 1.5-1.5" />
            </svg>
          </NavIcon>
          <NavIcon label={t('nav.messages')} path="/conversations" badge={chatUnreadCount}>
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </NavIcon>
          <NavIcon label={t('matching:matches', { defaultValue: t('nav.messages') })} path="/matches">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
            </svg>
          </NavIcon>
          <NavIcon label={t('nav.profile')} path="/profile">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </NavIcon>
        </div>
      </nav>
    </div>
  );
}
