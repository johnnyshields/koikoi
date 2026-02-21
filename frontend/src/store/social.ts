import { create } from 'zustand';
import { socialApi } from '../api/social';
import type { Connection, SocialStatus, InviteStats } from '../types';

interface SocialState {
  friends: Connection[];
  pendingRequests: Connection[];
  matchmakers: Connection[];
  subjects: Connection[];
  socialStatus: SocialStatus | null;
  inviteStats: InviteStats | null;
  isLoading: boolean;
  error: string | null;

  fetchFriends: () => Promise<void>;
  fetchPendingRequests: () => Promise<void>;
  fetchMatchmakers: () => Promise<void>;
  fetchSubjects: () => Promise<void>;
  fetchSocialStatus: () => Promise<void>;
  fetchInviteStats: () => Promise<void>;
  sendFriendRequest: (userId: string) => Promise<void>;
  acceptFriendRequest: (id: string) => Promise<void>;
  declineFriendRequest: (id: string) => Promise<void>;
  removeFriend: (friendId: string) => Promise<void>;
  updateTrustTier: (id: string, tier: Connection['trust_tier']) => Promise<void>;
  inviteMatchmaker: (userId: string) => Promise<void>;
  acceptMatchmakerInvite: (id: string) => Promise<void>;
  declineMatchmakerInvite: (id: string) => Promise<void>;
  removeMatchmaker: (id: string) => Promise<void>;
  redeemInvite: (code: string) => Promise<void>;
  clearError: () => void;
}

export const useSocialStore = create<SocialState>((set, get) => ({
  friends: [],
  pendingRequests: [],
  matchmakers: [],
  subjects: [],
  socialStatus: null,
  inviteStats: null,
  isLoading: false,
  error: null,

  fetchFriends: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await socialApi.getFriends();
      set({ friends: data.connections, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch friends';
      set({ error: message, isLoading: false });
    }
  },

  fetchPendingRequests: async () => {
    try {
      const { data } = await socialApi.getPendingRequests();
      set({ pendingRequests: data.connections });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch pending requests';
      set({ error: message });
    }
  },

  fetchMatchmakers: async () => {
    try {
      const { data } = await socialApi.getMatchmakers();
      set({ matchmakers: data.connections });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch matchmakers';
      set({ error: message });
    }
  },

  fetchSubjects: async () => {
    try {
      const { data } = await socialApi.getSubjects();
      set({ subjects: data.connections });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch subjects';
      set({ error: message });
    }
  },

  fetchSocialStatus: async () => {
    try {
      const { data } = await socialApi.getSocialStatus();
      set({
        socialStatus: {
          matchmaking_active: data.matchmaking_active,
          matchmaker_count: data.matchmaker_count,
          matchmakers_required: data.matchmakers_required,
        },
      });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch social status';
      set({ error: message });
    }
  },

  fetchInviteStats: async () => {
    try {
      const { data } = await socialApi.getInviteStats();
      set({ inviteStats: data.stats });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch invite stats';
      set({ error: message });
    }
  },

  sendFriendRequest: async (userId) => {
    try {
      await socialApi.sendFriendRequest(userId);
      await get().fetchFriends();
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to send friend request';
      set({ error: message });
      throw err;
    }
  },

  acceptFriendRequest: async (id) => {
    try {
      await socialApi.acceptFriendRequest(id);
      set({
        pendingRequests: get().pendingRequests.filter((r) => r.id !== id),
      });
      await get().fetchFriends();
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to accept friend request';
      set({ error: message });
      throw err;
    }
  },

  declineFriendRequest: async (id) => {
    try {
      await socialApi.declineFriendRequest(id);
      set({
        pendingRequests: get().pendingRequests.filter((r) => r.id !== id),
      });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to decline friend request';
      set({ error: message });
      throw err;
    }
  },

  removeFriend: async (friendId) => {
    try {
      await socialApi.removeFriend(friendId);
      set({ friends: get().friends.filter((f) => f.id !== friendId) });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to remove friend';
      set({ error: message });
      throw err;
    }
  },

  updateTrustTier: async (id, tier) => {
    try {
      const { data } = await socialApi.updateTrustTier(id, tier);
      set({
        friends: get().friends.map((f) => (f.id === id ? data.connection : f)),
      });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to update trust tier';
      set({ error: message });
      throw err;
    }
  },

  inviteMatchmaker: async (userId) => {
    try {
      await socialApi.inviteMatchmaker(userId);
      await get().fetchMatchmakers();
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to invite matchmaker';
      set({ error: message });
      throw err;
    }
  },

  acceptMatchmakerInvite: async (id) => {
    try {
      await socialApi.acceptMatchmakerInvite(id);
      await get().fetchSubjects();
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to accept matchmaker invite';
      set({ error: message });
      throw err;
    }
  },

  declineMatchmakerInvite: async (id) => {
    try {
      await socialApi.declineMatchmakerInvite(id);
      await get().fetchSubjects();
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to decline matchmaker invite';
      set({ error: message });
      throw err;
    }
  },

  removeMatchmaker: async (id) => {
    try {
      await socialApi.removeMatchmaker(id);
      set({ matchmakers: get().matchmakers.filter((m) => m.id !== id) });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to remove matchmaker';
      set({ error: message });
      throw err;
    }
  },

  redeemInvite: async (code) => {
    try {
      await socialApi.redeemInvite(code);
      await get().fetchFriends();
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to redeem invite';
      set({ error: message });
      throw err;
    }
  },

  clearError: () => set({ error: null }),
}));
