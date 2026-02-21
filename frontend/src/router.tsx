import { createBrowserRouter } from 'react-router-dom';
import { AuthGuard } from './components/guards/AuthGuard';
import { GuestGuard } from './components/guards/GuestGuard';
import { AppLayout } from './components/layout/AppLayout';
import { AuthLayout } from './components/layout/AuthLayout';
import { HomePage } from './pages/HomePage';
import { LoginPage } from './pages/auth/LoginPage';
import { RegisterPage } from './pages/auth/RegisterPage';
import { VerifyPhonePage } from './pages/auth/VerifyPhonePage';
import { MyProfilePage } from './pages/profile/MyProfilePage';
import { ProfileEditPage } from './pages/profile/ProfileEditPage';
import { ProfileViewPage } from './pages/profile/ProfileViewPage';
import { FriendsPage } from './pages/social/FriendsPage';
import { MatchmakersPage } from './pages/social/MatchmakersPage';
import { InvitePage } from './pages/social/InvitePage';
import { CardDealingPage } from './pages/matching/CardDealingPage';
import { MatchesPage } from './pages/matching/MatchesPage';
import { MatchDetailPage } from './pages/matching/MatchDetailPage';
import { MatchmakerDashboardPage } from './pages/matching/MatchmakerDashboardPage';
import { ColdStartPage } from './pages/matching/ColdStartPage';
import { ConversationsPage } from './pages/chat/ConversationsPage';
import { ChatPage } from './pages/chat/ChatPage';
import { NotificationsPage } from './pages/notifications/NotificationsPage';
import { SubscriptionPage } from './pages/billing/SubscriptionPage';
import { CreditsPage } from './pages/billing/CreditsPage';
import { PaymentSuccessPage } from './pages/billing/PaymentSuccessPage';

export const router = createBrowserRouter([
  {
    path: '/',
    element: (
      <AuthGuard>
        <AppLayout />
      </AuthGuard>
    ),
    children: [
      { index: true, element: <HomePage /> },
      { path: 'profile', element: <MyProfilePage /> },
      { path: 'profile/edit', element: <ProfileEditPage /> },
      { path: 'profile/:userId', element: <ProfileViewPage /> },
      { path: 'friends', element: <FriendsPage /> },
      { path: 'matchmakers', element: <MatchmakersPage /> },
      { path: 'invite', element: <InvitePage /> },
      { path: 'matching', element: <CardDealingPage /> },
      { path: 'matches', element: <MatchesPage /> },
      { path: 'matches/:matchId', element: <MatchDetailPage /> },
      { path: 'matchmaker-dashboard', element: <MatchmakerDashboardPage /> },
      { path: 'cold-start', element: <ColdStartPage /> },
      { path: 'conversations', element: <ConversationsPage /> },
      { path: 'conversations/:conversationId', element: <ChatPage /> },
      { path: 'notifications', element: <NotificationsPage /> },
      { path: 'subscription', element: <SubscriptionPage /> },
      { path: 'credits', element: <CreditsPage /> },
      { path: 'payment-success', element: <PaymentSuccessPage /> },
    ],
  },
  {
    path: '/login',
    element: (
      <GuestGuard>
        <AuthLayout />
      </GuestGuard>
    ),
    children: [{ index: true, element: <LoginPage /> }],
  },
  {
    path: '/register',
    element: (
      <GuestGuard>
        <AuthLayout />
      </GuestGuard>
    ),
    children: [{ index: true, element: <RegisterPage /> }],
  },
  {
    path: '/verify-phone',
    element: (
      <AuthGuard>
        <AuthLayout />
      </AuthGuard>
    ),
    children: [{ index: true, element: <VerifyPhonePage /> }],
  },
]);
