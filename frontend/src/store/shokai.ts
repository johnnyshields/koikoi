import { create } from 'zustand';
import { shokaiApi } from '../api/shokai';
import type { ShokaiCard, ShokaiSuggestion } from '../types';

interface ShokaiState {
  pending: ShokaiCard[];
  sent: ShokaiCard[];
  suggestions: ShokaiSuggestion[];
  isLoading: boolean;
  error: string | null;

  fetchPending: () => Promise<void>;
  fetchSent: () => Promise<void>;
  fetchSuggestions: () => Promise<void>;
  createShokai: (personAId: string, personBId: string, note?: string) => Promise<ShokaiCard | null>;
  respondToShokai: (id: string, response: 'accepted' | 'declined') => Promise<{ shokai: ShokaiCard; conversationId: string | null } | null>;
  clearError: () => void;
}

export const useShokaiStore = create<ShokaiState>((set, get) => ({
  pending: [],
  sent: [],
  suggestions: [],
  isLoading: false,
  error: null,

  fetchPending: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await shokaiApi.getPending();
      set({ pending: data.shokais, isLoading: false });
    } catch {
      set({ error: 'Failed to fetch pending shokais', isLoading: false });
    }
  },

  fetchSent: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await shokaiApi.getSent();
      set({ sent: data.shokais, isLoading: false });
    } catch {
      set({ error: 'Failed to fetch sent shokais', isLoading: false });
    }
  },

  fetchSuggestions: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await shokaiApi.getSuggestions();
      set({ suggestions: data.suggestions, isLoading: false });
    } catch {
      set({ error: 'Failed to fetch suggestions', isLoading: false });
    }
  },

  createShokai: async (personAId, personBId, note) => {
    try {
      const { data } = await shokaiApi.create(personAId, personBId, note);
      set({ sent: [data.shokai, ...get().sent] });
      return data.shokai;
    } catch {
      set({ error: 'Failed to create shokai' });
      return null;
    }
  },

  respondToShokai: async (id, response) => {
    try {
      const { data } = await shokaiApi.respond(id, response);
      set({
        pending: get().pending.map((s) => (s.id === id ? data.shokai : s)),
      });
      return { shokai: data.shokai, conversationId: data.conversation_id };
    } catch {
      set({ error: 'Failed to respond to shokai' });
      return null;
    }
  },

  clearError: () => set({ error: null }),
}));
