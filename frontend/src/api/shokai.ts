import apiClient from './client';
import type { ShokaiCard, ShokaiSuggestion } from '../types';

export const shokaiApi = {
  create: (personAId: string, personBId: string, note?: string, sourceConversationId?: string) =>
    apiClient.post<{ shokai: ShokaiCard }>('/shokai', {
      person_a_id: personAId,
      person_b_id: personBId,
      note,
      source_conversation_id: sourceConversationId,
    }),

  getPending: () =>
    apiClient.get<{ shokais: ShokaiCard[] }>('/shokai/pending'),

  getSent: () =>
    apiClient.get<{ shokais: ShokaiCard[] }>('/shokai/sent'),

  getSuggestions: () =>
    apiClient.get<{ suggestions: ShokaiSuggestion[] }>('/shokai/suggestions'),

  get: (id: string) =>
    apiClient.get<{ shokai: ShokaiCard }>(`/shokai/${id}`),

  respond: (id: string, response: 'accepted' | 'declined') =>
    apiClient.post<{ shokai: ShokaiCard; conversation_id: string | null }>(
      `/shokai/${id}/respond`,
      { response },
    ),
};
