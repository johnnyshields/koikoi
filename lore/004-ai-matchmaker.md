# 004 - AI Matchmaker (恋のキューピッド)

## Summary
Rule-based AI matchmaker system that generates compatibility ratings during cold start, when users have few human matchmaker ratings.

## Architecture

### Backend (Elixir/Phoenix)

**New modules under `lib/koikoi/ai_matchmaker/`:**

- **`ProfileAnalyzer`** - Deterministic compatibility scoring between two profiles using weighted factors:
  - Tag similarity (25%) - Jaccard similarity of tag values
  - Lifestyle alignment (20%) - Drinking/smoking preference matching
  - Location proximity (15%) - Prefecture/city comparison with adjacency lookup
  - Age compatibility (15%) - Check against each user's preferred age ranges
  - Relationship goals (15%) - Marriage intent and children preferences
  - Profile quality (10%) - Average completeness score
  - Output: 1-5 rating, confidence level, top 3 reasons (bilingual ja/en)

- **`Persona`** - AI matchmaker identity (恋のキューピッド / Love's Cupid) with note generation templates

- **`ColdStartWorker`** - GenServer running every 10 minutes:
  1. Finds users with matchmaking active but <5 total pair ratings
  2. For eligible pairs with <3 ratings, runs ProfileAnalyzer
  3. Submits ratings via `Matching.submit_rating/4` with `is_ai: true`
  4. Max 5 AI ratings per user per run

- **`AiMatchmaker`** (context module) - Public API: `analyze_pair/2`, `get_ai_persona/0`, `get_ai_ratings_for_user/1`, `trigger_cold_start_for_user/1`

**Controller:** `AiMatchmakerController` with 4 endpoints under `/api/v1/ai-matchmaker/`

### Frontend (React/TypeScript)

- **`src/api/aiMatchmaker.ts`** - API client for AI matchmaker endpoints
- **`AiPersonaBadge`** - Violet-themed badge with AI persona name and avatar
- **`AiMatchNote`** - Speech bubble display for AI-generated notes
- **`ColdStartPage`** - Onboarding page showing matchmaker invite progress, AI persona intro, and trigger button

### i18n
Added 11 new keys to both `ja/matching.json` and `en/matching.json` for AI matchmaker UI strings.

## Design Decisions

1. **No LLM** - Pure rule-based scoring for deterministic, fast, and cost-free operation
2. **AI ratings weighted 0.3x** - Already implemented in CompatibilityScorer, AI ratings have lower influence than human ratings
3. **Cold start threshold** - Users need 2+ matchmakers but fewer than 5 pair ratings to qualify
4. **GenServer worker** - Consistent with existing MatchExpirationWorker pattern in the supervision tree
5. **Bilingual reasons** - Each compatibility reason has both Japanese and English descriptions for i18n
