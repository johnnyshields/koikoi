import { create } from 'zustand';
import { matchingApi } from '../api/matching';
import type { MatchPair, Match, MatchmakerStats } from '../types';

interface MatchingState {
  pairs: MatchPair[];
  currentPairIndex: number;
  matches: Match[];
  stats: MatchmakerStats | null;
  isLoading: boolean;
  isDealingCards: boolean;
  error: string | null;

  dealCards: () => Promise<void>;
  submitRating: (
    person_a_id: string,
    person_b_id: string,
    rating: number,
    confidence: string,
    note?: string,
  ) => Promise<{ status: string }>;
  skipPair: (person_a_id: string, person_b_id: string) => Promise<void>;
  fetchMatches: (opts?: { status?: string; page?: number; limit?: number }) => Promise<void>;
  respondToMatch: (matchId: string, response: 'accepted' | 'declined') => Promise<void>;
  fetchStats: () => Promise<void>;
  nextPair: () => void;
  previousPair: () => void;
  clearError: () => void;
}

export const useMatchingStore = create<MatchingState>((set, get) => ({
  pairs: [],
  currentPairIndex: 0,
  matches: [],
  stats: null,
  isLoading: false,
  isDealingCards: false,
  error: null,

  dealCards: async () => {
    set({ isDealingCards: true, error: null });
    try {
      const { data } = await matchingApi.getCards();
      set({ pairs: data.pairs, currentPairIndex: 0, isDealingCards: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to deal cards';
      set({ error: message, isDealingCards: false });
    }
  },

  submitRating: async (person_a_id, person_b_id, rating, confidence, note) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await matchingApi.submitRating({
        person_a_id,
        person_b_id,
        rating,
        confidence,
        note,
      });
      const { pairs, currentPairIndex } = get();
      if (currentPairIndex < pairs.length - 1) {
        set({ currentPairIndex: currentPairIndex + 1, isLoading: false });
      } else {
        set({ isLoading: false });
      }
      return data.match_result;
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to submit rating';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  skipPair: async (person_a_id, person_b_id) => {
    set({ isLoading: true, error: null });
    try {
      await matchingApi.skipPair(person_a_id, person_b_id);
      const { pairs, currentPairIndex } = get();
      if (currentPairIndex < pairs.length - 1) {
        set({ currentPairIndex: currentPairIndex + 1, isLoading: false });
      } else {
        set({ isLoading: false });
      }
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to skip pair';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  fetchMatches: async (opts) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await matchingApi.getMatches(opts);
      set({ matches: data.matches, isLoading: false });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch matches';
      set({ error: message, isLoading: false });
    }
  },

  respondToMatch: async (matchId, response) => {
    set({ isLoading: true, error: null });
    try {
      const { data } = await matchingApi.respondToMatch(matchId, response);
      set({
        matches: get().matches.map((m) => (m.id === matchId ? data.match : m)),
        isLoading: false,
      });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to respond to match';
      set({ error: message, isLoading: false });
      throw err;
    }
  },

  fetchStats: async () => {
    try {
      const { data } = await matchingApi.getStats();
      set({ stats: data.stats });
    } catch (err: unknown) {
      const message =
        (err as { response?: { data?: { error?: string } } }).response?.data
          ?.error || 'Failed to fetch stats';
      set({ error: message });
    }
  },

  nextPair: () => {
    const { currentPairIndex, pairs } = get();
    if (currentPairIndex < pairs.length - 1) {
      set({ currentPairIndex: currentPairIndex + 1 });
    }
  },

  previousPair: () => {
    const { currentPairIndex } = get();
    if (currentPairIndex > 0) {
      set({ currentPairIndex: currentPairIndex - 1 });
    }
  },

  clearError: () => set({ error: null }),
}));
