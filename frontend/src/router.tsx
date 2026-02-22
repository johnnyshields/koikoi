import { createBrowserRouter } from 'react-router-dom';
import { AuthGuard } from './components/guards/AuthGuard';
import { GuestGuard } from './components/guards/GuestGuard';
import { AppLayout } from './components/layout/AppLayout';
import { AuthLayout } from './components/layout/AuthLayout';
import { LoginPage } from './pages/auth/LoginPage';
import { RegisterPage } from './pages/auth/RegisterPage';
import { VerifyPhonePage } from './pages/auth/VerifyPhonePage';
import { MyProfilePage } from './pages/profile/MyProfilePage';
import { ProfileEditPage } from './pages/profile/ProfileEditPage';
import { ProfileViewPage } from './pages/profile/ProfileViewPage';
import { InvitePage } from './pages/social/InvitePage';
import { ConversationsPage } from './pages/chat/ConversationsPage';
import { ChatPage } from './pages/chat/ChatPage';
import { CreateGroupPage } from './pages/chat/CreateGroupPage';
import { GroupSettingsPage } from './pages/chat/GroupSettingsPage';
import { ContactsPage } from './pages/contacts/ContactsPage';
import { ShokaiCreatePage } from './pages/shokai/ShokaiCreatePage';
import { ShokaiDetailPage } from './pages/shokai/ShokaiDetailPage';
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
      { index: true, element: <ConversationsPage /> },
      { path: 'contacts', element: <ContactsPage /> },
      { path: 'profile', element: <MyProfilePage /> },
      { path: 'profile/edit', element: <ProfileEditPage /> },
      { path: 'profile/:userId', element: <ProfileViewPage /> },
      { path: 'invite', element: <InvitePage /> },
      { path: 'conversations/new-group', element: <CreateGroupPage /> },
      { path: 'conversations/:conversationId/settings', element: <GroupSettingsPage /> },
      { path: 'conversations/:conversationId', element: <ChatPage /> },
      { path: 'shokai/create', element: <ShokaiCreatePage /> },
      { path: 'shokai/:shokaiId', element: <ShokaiDetailPage /> },
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
