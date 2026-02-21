import apiClient from './client';

export interface AiPersona {
  id: string;
  name_ja: string;
  name_en: string;
  avatar_url: string;
}

export interface AiReason {
  type: string;
  description_ja: string;
  description_en: string;
  weight: number;
}

export interface AiAnalysis {
  score: number;
  confidence: 'low' | 'medium' | 'high';
  reasons: AiReason[];
  note_ja: string;
  note_en: string;
  persona: AiPersona;
}

export interface AiRating {
  id: string;
  matchmaker_id: string;
  person_a_id: string;
  person_b_id: string;
  rating: number;
  confidence: string;
  signals: { shared_tags: string[]; matchmaker_note: string | null };
  is_ai: boolean;
  inserted_at: string;
}

export const aiMatchmakerApi = {
  getPersona: () =>
    apiClient.get<{ persona: AiPersona }>('/ai-matchmaker/persona'),

  getAnalysis: (userAId: string, userBId: string) =>
    apiClient.get<{ analysis: AiAnalysis }>(
      `/ai-matchmaker/analysis/${userAId}/${userBId}`,
    ),

  triggerColdStart: () =>
    apiClient.post<{ message: string }>('/ai-matchmaker/trigger'),

  getAiRatings: () =>
    apiClient.get<{ ratings: AiRating[]; persona: AiPersona }>(
      '/ai-matchmaker/ratings',
    ),
};
