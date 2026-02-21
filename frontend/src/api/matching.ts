import apiClient from './client';
import type { MatchPair, MatchingSession, Match, MatchmakerStats } from '../types';

export const matchingApi = {
  // Card dealing
  getCards: () =>
    apiClient.get<{ pairs: MatchPair[] }>('/matching/cards'),

  // Rating
  submitRating: (params: {
    person_a_id: string;
    person_b_id: string;
    rating: number;
    confidence: string;
    note?: string;
  }) =>
    apiClient.post<{ session: MatchingSession; match_result: { status: string } }>(
      '/matching/rate',
      params,
    ),

  skipPair: (person_a_id: string, person_b_id: string) =>
    apiClient.post<{ message: string }>('/matching/skip', { person_a_id, person_b_id }),

  // Matches
  getMatches: (params?: { status?: string; page?: number; limit?: number }) =>
    apiClient.get<{ matches: Match[] }>('/matches', { params }),

  getMatch: (matchId: string) =>
    apiClient.get<{ match: Match }>(`/matches/${matchId}`),

  respondToMatch: (matchId: string, response: 'accepted' | 'declined') =>
    apiClient.post<{ match: Match }>(`/matches/${matchId}/respond`, { response }),

  // Stats
  getStats: () =>
    apiClient.get<{ stats: MatchmakerStats }>('/matching/stats'),
};
