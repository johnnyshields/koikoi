# 002 - Initial Build Summary

## Date: 2026-02-21

## Overview

Complete greenfield build of Koikoi across 6 phases in a single session. The entire app — backend, frontend, database seeds, and all feature domains — was built from an empty directory to a running application with 175 files and ~24,000 lines of code.

Build was executed using parallel agent teams per phase, with 2-3 agents working concurrently on backend, frontend, and database tasks.

## Phase 1: Foundation

### Backend Skeleton
- Generated Phoenix project with `--no-html --no-assets --no-live --no-mailer --no-tailwind` (API-only)
- Configured deps: `mongodb_driver` 1.6, `guardian` 2.3, `argon2_elixir` 4.0, `corsica` 2.1, `stripity_stripe` 3.2, `jason`, `bandit`
- Created `Koikoi.Repo` — a thin wrapper around the `Mongo` driver (NOT an Ecto repo). Provides `insert_one`, `find_one`, `find`, `update_one`, `delete_one`, `count_documents`, `aggregate`, `create_index` all delegating to the `Mongo` module with a named `:mongo` connection
- Configured MongoDB connection via WSL2 gateway IP (`172.29.208.1:27017/koikoi_dev`) in `config/dev.exs`
- Set up Guardian with `subject_for_token`/`resource_from_claims` in `Koikoi.Accounts.Guardian`
- Auth pipeline plug (`VerifyHeader` → `EnsureAuthenticated` → `LoadResource`)
- CORS via Corsica allowing `localhost:5173` and `localhost:3000`
- Gettext configured for `ja` and `en`

### Frontend Scaffold
- Vite 7 + React 19 + TypeScript project
- TailwindCSS v4, react-router-dom, i18next, axios, zustand
- API client (`src/api/client.ts`) with JWT interceptor: auto-attaches Bearer token, auto-refreshes on 401, sends `Accept-Language` header
- Auth pages: Login, Register, VerifyPhone
- `useAuth` hook wrapping the Zustand auth store
- Route guards: `AuthGuard` (redirects to login) and `GuestGuard` (redirects to home)
- Shared UI library: Button, Input, Card, Modal, Avatar, LoadingSpinner, Toast
- Mobile-first `AppLayout` with bottom nav (ホーム, マッチング, メッセージ, 通知, プロフィール) and `AuthLayout` for guest pages

### Database & Seeds
- `Seeds.Setup` — creates MongoDB indexes for all 11 collections
- `Seeds.TagsCatalog` — 200 predefined Japanese tags across categories (趣味, スポーツ, 食べ物, 音楽, 旅行, ライフスタイル, 性格, 価値観, etc.)
- `Seeds.TestUsers` — 10 users (5 female, 5 male) with Japanese names, bios, occupations, locations, and tag associations

## Phase 2: Profiles + Social Graph

### Profile Backend (`Koikoi.Profiles`)
- Full CRUD with `create_profile`, `update_profile`, `get_profile`
- Privacy filtering via `get_profile_for_viewer/2` — calls `Social.get_trust_tier/2` to determine visibility level, then strips fields accordingly (inner_circle=full, friends=summary, verified=minimal, open=basic)
- Photo upload: multipart file → local filesystem at `priv/static/uploads/photos/{user_id}/`. Max 6 photos. Thumbnails created (currently just copies). Reorder and set-primary supported
- Tag management: add/remove tags on profiles, linked to the `tags_catalog` collection
- Profile completeness scoring: weighted formula (nickname 10%, location 10%, photo 20%, bio 10%, physical 10%, career 10%, lifestyle 5%, relationship 10%, tags 10%, preferences 5%)
- Photo serving via `Plug.Static` at `/uploads` path in `endpoint.ex`

### Social Graph Backend (`Koikoi.Social`)
- **Friend connections** — bidirectional: send request → accept/decline → accepted status. Queries use `$or` to match either direction
- **Matchmaker relationships** — directed: user invites someone to be their matchmaker. `subject_id` = the person being matched, `matchmaker_id` = the person doing the matching
- **Trust tiers** — per-connection setting: `inner_circle`, `friends`, `verified`, `open`. Determines profile visibility. `get_trust_tier/2` checks friend connection first, then matchmaker relationship, defaults to `open`
- **Invite codes** — each user gets one at registration. Redeeming creates a pending friend request and increments `matchmaker_invites_sent` counter
- **Activation check** — `is_matchmaking_active?/1` requires 2+ accepted matchmaker relationships before the user can appear in card dealing

### Profile + Social Frontend
- **ProfileEditPage** — multi-step wizard (basic info → physical → career → lifestyle → relationship → preferences)
- **PhotoUpload** component with drag-and-drop, reorder, and primary selection
- **TagSelector** — searchable tag picker with categories, shows selected tags as removable pills
- **ProfileViewPage** — tiered display based on viewer's trust level
- **FriendsPage** / **MatchmakersPage** — list views with pending request management
- **InvitePage** — shows invite code, share link, and invite stats
- **CompletenessBar** — visual progress indicator

## Phase 3: Matchmaking Engine

### Card Dealer (`Koikoi.Matching.CardDealer`)
Pair selection algorithm:
1. `Social.get_matchable_users/1` — gets all user IDs the matchmaker has permission to match
2. Generates all cross-gender-preference canonical pairs (person_a_id < person_b_id alphabetically)
3. Filters out pairs already rated by this matchmaker and pairs with active matches
4. Scores each pair: tag_overlap (30%) + profile_completeness (20%) + cold_pair_bonus (20%) + matchmaker_familiarity (20%) - freshness_penalty (10%)
5. Returns top 10 pairs sorted descending by score

### Compatibility Scorer (`Koikoi.Matching.CompatibilityScorer`)
Aggregates all ratings for a pair into a single compatibility score:
- Each rating weight = `confidence_mult × tier_mult × recency_mult`
- Confidence multipliers: low=0.5, medium=1.0, high=1.5
- Tier multipliers: both_inner_circle=2.0, one_inner=1.5, friends=1.0
- Recency decay: ≤7d=1.0, ≤30d=0.9, ≤90d=0.8, older=0.6
- AI ratings get additional 0.3x multiplier
- Final score = weighted average of normalized ratings (1-5 → 0-1 scale)

### Match Aggregator (`Koikoi.Matching.MatchAggregator`)
- After each rating submission, checks if the pair crosses match threshold
- Normal threshold: 3+ human ratings, score ≥ 0.70, 2+ strong ratings (≥4)
- Cold start threshold: 2 human + 1 AI, score ≥ 0.75, 2+ strong ratings
- Creates match document with `signal_summary` (shared tags, top matchmaker notes, strong rating count)
- Introduction flow: both parties get 72 hours to accept/decline. If both accept → conversation auto-created
- `MatchExpirationWorker` (GenServer) checks every 5 minutes for expired pending introductions

### Matching Frontend
- **CardDealingPage** — the signature UX. Shows pair cards that matchmakers swipe through. Each card shows both people's photos, names, shared tags
- **RatingModal** — 1-5 star rating with confidence selector (low/medium/high) and optional note
- **PairCard** component with `SharedTagsBadge` highlighting common interests
- **MatchesPage** — list of all matches with status indicators
- **MatchDetailPage** — full match info with signal summary, accept/decline buttons
- **MatchmakerDashboardPage** — stats and gamification (total ratings, successful matches, accuracy)

## Phase 4: AI Matchmaker

See `lore/004-ai-matchmaker.md` for detailed architecture.

Built concurrently with Phase 5 (Chat). Key modules:
- `ProfileAnalyzer` — deterministic compatibility scoring (no LLM)
- `Persona` — AI identity "恋のキューピッド" with templated Japanese match notes
- `ColdStartWorker` — GenServer generating AI ratings every 10 minutes
- `ColdStartPage` — onboarding showing matchmaker invite progress and AI persona

## Phase 5: Chat + Notifications

### Chat Backend (`Koikoi.Chat`)
- Conversations auto-created when both parties accept a match introduction
- Messages with sender tracking, timestamps, read receipts
- Subscription check: women message free, men need active paid subscription
- `ChatChannel` (Phoenix Channel) — events: `new_message`, `typing`, `mark_read`

### Notifications Backend (`Koikoi.Notifications`)
- Persisted notifications with `type`, `title`, `body`, `data`, `read` status
- Types: new_match, message, matchmaker_request, matchmaker_success, match_expired
- PubSub broadcasting for real-time delivery
- `NotificationChannel` (Phoenix Channel) — subscribes to user-specific PubSub topic

### WebSocket Layer
- `UserSocket` authenticates via JWT token parameter
- Channels: `chat:{conversation_id}` and `notifications:{user_id}`

### Chat + Notifications Frontend
- **ConversationsPage** — list of conversations with last message preview, unread count
- **ChatPage** — real-time messaging with typing indicators, auto-scroll, message grouping
- **NotificationsPage** — notification list with read/unread state, mark-all-read
- **NotificationBell** — header component with unread badge count
- **useSocket** hook — singleton Phoenix socket connection management
- **useChannel** hook — subscribe to a channel with event handler registration, auto-cleanup

## Phase 6: Billing + Polish

### Billing Backend (`Koikoi.Billing`)
- Stripe integration via `stripity_stripe`
- Plans: Basic (¥3,980/mo, messaging unlock) and VIP (¥6,980/mo, read receipts + priority)
- Credit packages: 100 credits (¥480), 300 credits (¥1,280), 500 credits (¥1,980)
- Checkout session creation for subscriptions and credit purchases
- Webhook handler for `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
- Credit transaction ledger with `purchase`/`spend` types
- `StripeWebhook` plug — captures raw request body for Stripe signature verification

### Billing Frontend
- **SubscriptionPage** — plan comparison cards with current plan indicator
- **CreditsPage** — balance display, package selection, transaction history
- **PaymentSuccessPage** — post-checkout confirmation
- **PremiumBadge** / **SubscriptionBanner** — premium feature indicators and upsell prompts

## Smoke Test Results

Both servers started successfully:
- Backend: Phoenix on `http://localhost:4000` (Bandit adapter)
- Frontend: Vite on `http://localhost:5174` (5173 was occupied)

Seeds loaded: 200 tags, 10 test users with profiles.

### Endpoints Verified Working
- `POST /api/v1/auth/login` — returns JWT tokens
- `GET /api/v1/auth/me` — returns authenticated user
- `GET /api/v1/billing/plans` — returns subscription plans

### Bugs Found
Three runtime serialization errors documented in CLAUDE.md "Known Issues":
1. `GET /api/v1/tags` — 500 from `BSON.ObjectId` not being JSON-serializable
2. `GET /api/v1/social/status` — 500 from `Repo.count_documents` returning `{:ok, count}` tuple instead of integer
3. `GET /api/v1/profile` — returns null for seed users due to `user_id` type mismatch (string vs ObjectId)

## File Count

| Area | Files |
|------|-------|
| Backend (Elixir) | ~75 |
| Frontend (React/TS) | ~85 |
| Config/i18n/misc | ~15 |
| **Total** | **175 files, ~24,000 lines** |

## Technical Debt & Next Steps

1. Fix the three runtime bugs (BSON serialization, tuple unwrapping, seed user_id type)
2. Photo thumbnails are currently just file copies — need actual image resizing (probably via `Mogrify` or `Image`)
3. SMS verification is mocked (always accepts code "123456") — need real SMS provider (Twilio, etc.)
4. Stripe webhook secret is a placeholder — need real Stripe test keys
5. No rate limiting on API endpoints yet
6. Frontend has no automated tests (Vitest configured but no test files)
7. Backend tests exist but may not pass without MongoDB connection
8. No production config or deployment setup
9. File storage is local filesystem only — needs S3 for production
10. The AI matchmaker's location proximity scoring uses a simple prefecture equality check — could use actual geographic distance
