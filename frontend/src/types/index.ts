export interface User {
  id: string;
  phone_number: string;
  gender: string;
  date_of_birth: string;
  age_verified: boolean;
  phone_verified: boolean;
  subscription: {
    plan: string;
    expires_at: string | null;
  };
  credits: number;
  invite_code: string;
}

export interface Profile {
  user_id: string;
  nickname: string;
  location: { prefecture: string; city: string };
  hometown: string | null;
  physical: { height_cm: number | null; body_type: string | null; blood_type: string | null };
  career: { occupation: string | null; education: string | null; income_range: string | null };
  lifestyle: { drinking: string | null; smoking: string | null };
  relationship: { marriage_intent: string | null; has_children: boolean | null; wants_children: string | null };
  personality: string | null;
  bio: string | null;
  photos: ProfilePhoto[];
  tags: ProfileTag[];
  visibility: Record<string, string | null>;
  preferences: {
    age_range: { min: number; max: number };
    preferred_genders: string[];
    preferred_prefectures: string[] | null;
  };
  profile_completeness: number;
  inserted_at: string;
  updated_at: string;
}

export interface ProfilePhoto {
  id: string;
  url: string;
  thumbnail_url: string;
  order: number;
  is_primary: boolean;
}

export interface ProfileTag {
  category: string;
  value: string;
}

export interface TagCatalogItem {
  category: string;
  value: string;
  popularity: number;
}

export interface Connection {
  id: string;
  requester_id: string;
  recipient_id: string;
  type: 'friend' | 'matchmaker';
  trust_tier: 'inner_circle' | 'friends' | 'verified' | 'open';
  status: 'pending' | 'accepted' | 'declined' | 'blocked';
  matchmaker_id: string | null;
  subject_id: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface SocialStatus {
  matchmaking_active: boolean;
  matchmaker_count: number;
  matchmakers_required: number;
}

export interface InviteStats {
  invite_code: string;
  invites_sent: number;
}

export interface MatchPair {
  person_a: PairPerson;
  person_b: PairPerson;
  shared_tags: ProfileTag[];
  priority_score: number;
}

export interface PairPerson {
  user_id: string;
  nickname: string;
  primary_photo: ProfilePhoto | null;
  age: number | null;
  prefecture: string | null;
  tags: ProfileTag[];
  profile_completeness: number;
}

export interface MatchingSession {
  id: string;
  matchmaker_id: string;
  person_a_id: string;
  person_b_id: string;
  rating: number;
  confidence: string;
  signals: { shared_tags: string[]; matchmaker_note: string | null };
  is_ai: boolean;
  skipped: boolean;
}

export interface Match {
  id: string;
  person_a_id: string;
  person_b_id: string;
  status: 'pending_intro' | 'introduced' | 'chatting' | 'expired' | 'declined';
  compatibility_score: number;
  total_ratings: number;
  match_type: 'normal' | 'cold_start';
  signal_summary: {
    shared_tags: string[];
    top_matchmaker_notes: string[];
    strong_rating_count: number;
  };
  person_a_response: 'accepted' | 'declined' | null;
  person_b_response: 'accepted' | 'declined' | null;
  conversation_id: string | null;
  expires_at: string;
  inserted_at: string;
  updated_at: string;
}

export interface MatchmakerStats {
  total_ratings: number;
  successful_matches: number;
  average_rating: number;
  pairs_skipped: number;
  total_sessions: number;
}

export interface Message {
  id: string;
  match_id: string;
  sender_id: string;
  content: string;
  read_at: string | null;
  created_at: string;
}

export interface Conversation {
  id: string;
  type: 'dm' | 'group' | 'goukon' | 'shokai';
  match_id: string | null;
  name: string | null;
  admin_ids: string[] | null;
  participants: string[];
  status: 'active' | 'archived';
  last_message_at: string | null;
  last_message?: ChatMessage | null;
  expires_at: string | null;
  inserted_at: string;
  updated_at: string;
}

export interface ChatMessage {
  id: string;
  conversation_id: string;
  sender_id: string | null;
  content: string;
  message_type: 'text' | 'image' | 'stamp' | 'system' | 'shokai_card';
  read_at: string | null;
  read_by: Record<string, string> | null;
  shokai_card_id: string | null;
  inserted_at: string;
}

export interface MemberInfo {
  user_id: string;
  nickname: string | null;
  primary_photo: ProfilePhoto | null;
  is_admin: boolean;
}

export interface ShokaiCard {
  id: string;
  matchmaker_id: string;
  person_a_id: string;
  person_b_id: string;
  person_a_response: 'pending' | 'accepted' | 'declined';
  person_b_response: 'pending' | 'accepted' | 'declined';
  matchmaker_note: string | null;
  compatibility_hints: {
    shared_tags: string[];
    score: number | null;
  };
  status: 'pending' | 'accepted' | 'declined' | 'expired';
  result_conversation_id: string | null;
  expires_at: string;
  person_a_profile?: ProfileSummary | null;
  person_b_profile?: ProfileSummary | null;
  matchmaker_profile?: ProfileSummary | null;
  inserted_at: string;
  updated_at: string;
}

export interface ShokaiSuggestion {
  person_a: ProfileSummary;
  person_b: ProfileSummary;
  shared_tags: string[];
  priority_score: number;
}

export interface ProfileSummary {
  user_id: string;
  nickname: string | null;
  primary_photo: ProfilePhoto | null;
  age: number | null;
  prefecture: string | null;
  tags: ProfileTag[] | null;
}

export interface Notification {
  id: string;
  type: 'new_match' | 'match_accepted' | 'new_message' | 'matchmaker_request' | 'matchmaker_success' | 'match_expired';
  title: string;
  body: string;
  data: Record<string, string>;
  read: boolean;
  inserted_at: string;
}

export interface SubscriptionPlan {
  id: string;
  name_ja: string;
  name_en: string;
  price_jpy: number;
  features_ja: string[];
  features_en: string[];
}

export interface CreditPackage {
  id: string;
  credits: number;
  price_jpy: number;
  name_ja: string;
  name_en: string;
  popular?: boolean;
  best_value?: boolean;
}

export interface CreditTransaction {
  id: string;
  type: 'purchase' | 'spend' | 'bonus' | 'refund';
  amount: number;
  balance_after: number;
  description: string;
  inserted_at: string;
}

export interface SubscriptionInfo {
  plan: string;
  expires_at: string | null;
  is_active: boolean;
}
