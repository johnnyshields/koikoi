import apiClient from './client';
import type { Connection, InviteStats } from '../types';

export const socialApi = {
  // Friends
  sendFriendRequest: (userId: string) =>
    apiClient.post<{ connection: Connection }>('/friends/request', { user_id: userId }),

  acceptFriendRequest: (id: string) =>
    apiClient.post<{ connection: Connection }>(`/friends/${id}/accept`),

  declineFriendRequest: (id: string) =>
    apiClient.post<{ connection: Connection }>(`/friends/${id}/decline`),

  removeFriend: (friendId: string) =>
    apiClient.delete<{ message: string }>(`/friends/${friendId}`),

  getFriends: (params?: { page?: number; limit?: number }) =>
    apiClient.get<{ connections: Connection[] }>('/friends', { params }),

  getPendingRequests: () =>
    apiClient.get<{ connections: Connection[] }>('/friends/pending'),

  updateTrustTier: (id: string, tier: Connection['trust_tier']) =>
    apiClient.put<{ connection: Connection }>(`/friends/${id}/trust-tier`, { tier }),

  // Matchmakers
  inviteMatchmaker: (userId: string) =>
    apiClient.post<{ connection: Connection }>('/matchmakers/invite', { user_id: userId }),

  acceptMatchmakerInvite: (id: string) =>
    apiClient.post<{ connection: Connection }>(`/matchmakers/${id}/accept`),

  declineMatchmakerInvite: (id: string) =>
    apiClient.post<{ connection: Connection }>(`/matchmakers/${id}/decline`),

  removeMatchmaker: (id: string) =>
    apiClient.delete<{ message: string }>(`/matchmakers/${id}`),

  getMatchmakers: () =>
    apiClient.get<{ connections: Connection[] }>('/matchmakers'),

  getSubjects: () =>
    apiClient.get<{ connections: Connection[] }>('/matchmakers/subjects'),

  // Invites
  redeemInvite: (code: string) =>
    apiClient.post<{ connection: Connection }>('/invites/redeem', { code }),

  getInviteStats: () =>
    apiClient.get<{ stats: InviteStats }>('/invites/stats'),

  // Status
  getSocialStatus: () =>
    apiClient.get<{ matchmaking_active: boolean; matchmaker_count: number; matchmakers_required: number }>('/social/status'),
};
