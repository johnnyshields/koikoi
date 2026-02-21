# Koikoi (コイコイ) - Japanese Matchmaking Dating App

Friends-as-matchmakers dating app. Matchmakers rate pairs of their friends for compatibility; the system aggregates weighted ratings and creates matches when confidence thresholds are met. An AI matchmaker persona supplements during cold start.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Elixir 1.19 / Phoenix 1.8 (API-only, no HTML/LiveView) |
| Frontend | React 19 + TypeScript + Vite 7 + TailwindCSS v4 |
| Database | MongoDB via `mongodb_driver` 1.6 (thin `Koikoi.Repo` wrapper) |
| Auth | Guardian 2.3 (JWT) + Argon2 |
| Real-time | Phoenix Channels (WebSocket) |
| Payments | Stripe via `stripity_stripe` 3.2 |
| i18n | Gettext (backend) + i18next (frontend), Japanese primary |
| State | Zustand (frontend) |

## Project Structure

```
koikoi/
├── backend/                         # Elixir/Phoenix API
│   ├── lib/koikoi/                  # Business domain contexts
│   │   ├── accounts/                # Auth, users, phone verification
│   │   ├── profiles/                # Profile CRUD, photos, tags, privacy
│   │   ├── social/                  # Connections, trust tiers, invites
│   │   ├── matching/                # Card dealer, scorer, aggregator
│   │   ├── ai_matchmaker/           # AI persona, profile analyzer, cold start
│   │   ├── chat/                    # Conversations, messages
│   │   ├── notifications/           # Real-time + persisted notifications
│   │   ├── billing/                 # Stripe subscriptions, credits
│   │   ├── repo.ex                  # MongoDB wrapper (delegates to Mongo driver)
│   │   └── seeds/                   # Tags catalog, test users, DB setup
│   ├── lib/koikoi_web/              # Phoenix web layer
│   │   ├── controllers/             # JSON API controllers
│   │   ├── channels/                # WebSocket (chat, notifications)
│   │   ├── plugs/                   # Auth pipeline, locale, Stripe webhook
│   │   └── router.ex                # All routes under /api/v1/
│   ├── config/                      # Environment configs
│   └── test/
├── frontend/                        # React SPA
│   ├── src/
│   │   ├── api/                     # Axios API client (JWT interceptor)
│   │   ├── components/              # UI, layout, feature components
│   │   ├── pages/                   # Route-level pages
│   │   ├── hooks/                   # useAuth, useSocket, useChannel
│   │   ├── store/                   # Zustand stores
│   │   ├── i18n/                    # i18next config
│   │   ├── types/                   # TypeScript interfaces
│   │   └── data/                    # Static data (prefectures)
│   └── public/locales/{ja,en}/      # Translation JSON files (7 namespaces)
├── lore/                            # Architecture decision records
└── CLAUDE.md
```

## Development Environment (WSL2)

### MongoDB Connection
MongoDB runs on the **Windows host**, not inside WSL. Connect via the WSL2 gateway IP:
```bash
# Gateway IP (typically 172.29.208.1, can change on WSL restart)
ip route show default | awk '{print $3}'
```
The backend config in `config/dev.exs` defaults to `MONGODB_HOST=172.29.208.1`. Override with env var if the gateway changes. Database name: `koikoi_dev`.

Direct shell access:
```bash
mongosh --host $(ip route show default | awk '{print $3}') --port 27017 koikoi_dev
```

### Running the App

**Backend** (port 4000):
```bash
cd backend
mix deps.get
mix phx.server
```

**Frontend** (port 5173):
```bash
cd frontend
npm install
npm run dev
```

**Seed data** (200 tags + 10 test users):
```bash
cd backend
mix run -e "Koikoi.Seeds.run()"
```

Test user credentials: phone `+81901111001` through `+81901111005` (female), `+81902222001` through `+81902222005` (male), password `password123`.

### Testing
```bash
cd backend && mix test          # ExUnit
cd frontend && npm test         # Vitest
```

## Architecture & Conventions

### Backend (Elixir/Phoenix)

**Context modules** (`lib/koikoi/`) encapsulate business logic:
- `Accounts` — registration, login, JWT (access 15min + refresh 30d with rotation), phone verification (mocked SMS)
- `Profiles` — CRUD, photo upload (local filesystem), tags, privacy filtering by trust tier, completeness scoring
- `Social` — friend connections (bidirectional), matchmaker relationships (directed), trust tiers (inner_circle/friends/verified/open), invite codes
- `Matching` — CardDealer (pair selection), CompatibilityScorer (weighted aggregation), MatchAggregator (threshold-based match creation)
- `AiMatchmaker` — rule-based ProfileAnalyzer, AI persona (恋のキューピッド), ColdStartWorker (GenServer)
- `Chat` — conversations, messages, subscription checks (women free, men need paid plan)
- `Notifications` — persisted notifications with PubSub broadcasting
- `Billing` — Stripe subscriptions (basic ¥3,980/mo, VIP ¥6,980/mo), credit packages, webhook handling

**MongoDB access** — `Koikoi.Repo` is a thin wrapper around the `Mongo` driver (not an Ecto repo). Functions: `insert_one`, `find_one`, `find`, `update_one`, `delete_one`, `count_documents`, `aggregate`, `create_index`. Named connection: `:mongo`.

**BSON ObjectId handling** — MongoDB returns `BSON.ObjectId` structs. These are NOT JSON-serializable. Controllers must convert to strings before encoding (use `to_string/1`). When querying by user-supplied string IDs, decode with `BSON.ObjectId.decode/1`.

**Background jobs** — GenServer workers (no Oban, which requires PostgreSQL):
- `MatchExpirationWorker` — checks every 5 min for expired pending introductions
- `ColdStartWorker` — generates AI ratings every 10 min for cold-start users

**Controllers** return JSON only. All routes under `/api/v1/`. Router uses fixed paths before parameterized routes to avoid ambiguity.

### Frontend (React/TypeScript)

**Pages** (17 total across 8 domains): auth (Login, Register, VerifyPhone), profile (MyProfile, ProfileEdit, ProfileView), social (Friends, Matchmakers, Invite), matching (CardDealing, Matches, MatchDetail, MatchmakerDashboard, ColdStart), chat (Conversations, Chat), notifications, billing (Subscription, Credits, PaymentSuccess).

**API client** (`src/api/client.ts`) — Axios instance with JWT interceptor: auto-attaches token, auto-refreshes on 401, sends Accept-Language header.

**State** — Zustand stores: auth, profile, social, matching, chat, notifications, billing.

**WebSocket** — `useSocket` hook manages Phoenix socket connection; `useChannel` hook subscribes to channels with event handlers. Channels: `chat:{conversation_id}`, `notifications:{user_id}`.

**i18n** — i18next with 7 namespaces (common, auth, profile, social, matching, chat, billing) in `public/locales/{ja,en}/`. Japanese is the default language.

**Styling** — TailwindCSS v4, mobile-first responsive design.

### Database (MongoDB Collections)

| Collection | Purpose |
|-----------|---------|
| `users` | Auth data (phone, password hash, gender, DOB, subscription, credits) |
| `profiles` | Public-facing profile data (separate from users for security isolation) |
| `connections` | Social graph (friend + matchmaker relationships, trust tiers) |
| `matchmaking_sessions` | Individual matchmaker ratings of pairs |
| `matches` | Aggregated matches that crossed threshold |
| `conversations` | Chat conversations between matched pairs |
| `messages` | Chat messages |
| `notifications` | Persisted notifications with read state |
| `tags_catalog` | Master tag list (~200 predefined Japanese tags) |
| `phone_verifications` | Temporary SMS codes (TTL indexed) |
| `credit_transactions` | Credit ledger |

**Key conventions:**
- `users` and `profiles` are separate collections — auth data never leaks through profile queries
- Canonical pair ordering: always `person_a_id < person_b_id` to prevent duplicate pairs
- The seed script stores `user_id` as a string in profiles (via `to_string(user["_id"])`)

## Core Domain Logic

### Card-Dealing Matchmaking

1. Get all users the matchmaker has permission to match (via `Social.get_matchable_users/1`)
2. Generate all cross-preference canonical pairs (smaller_id first)
3. Filter out already-rated and actively-matched pairs
4. Score each pair for presentation priority:
   - Tag overlap (30%) — Jaccard similarity
   - Profile completeness (20%) — average of both profiles
   - Cold pair bonus (20%) — boost pairs with few existing ratings
   - Matchmaker familiarity (20%) — higher if inner_circle for both
   - Freshness penalty (-10%) — deprioritize pairs shown 10+ times without a match
5. Top 10 pairs dealt as cards

### Compatibility Scoring

Each rating weighted by: `confidence_mult × tier_mult × recency_mult × ai_mult`
- Confidence: low=0.5, medium=1.0, high=1.5
- Tier: both_inner=2.0, one_inner=1.5, friends=1.0
- Recency: ≤7d=1.0, ≤30d=0.9, ≤90d=0.8, older=0.6
- AI: additional 0.3x multiplier

### Match Thresholds

- **Normal**: 3+ human ratings AND score ≥ 0.70 AND 2+ strong ratings (≥4)
- **Cold start**: 2 human + 1 AI AND score ≥ 0.75 AND 2+ strong ratings
- Both parties get 72 hours to accept/decline introduction
- If both accept → conversation opens

### AI Matchmaker (恋のキューピッド)

Rule-based (no LLM). ProfileAnalyzer scores: tag similarity (25%), lifestyle alignment (20%), location proximity (15%), age compatibility (15%), relationship goals (15%), profile quality (10%). AI ratings weighted 0.3x vs human. ColdStartWorker runs every 10 min for users with <5 total pair ratings.

### Trust Tiers & Privacy

| Tier | Profile Visibility |
|------|-------------------|
| inner_circle | Full profile |
| friends | Photo, age, area, top 5 tags, truncated bio |
| verified | Photo, nickname, prefecture, age |
| open | Photo and nickname only |

Users control tier per-connection. Matchmakers need inner_circle or friends access to rate pairs.

### Monetization

- Men: free to browse/match, paid (basic ¥3,980/mo) to message
- Women: free including messaging
- Credits for boosts/extras
- VIP tier (¥6,980/mo) with read receipts, priority matching

## Known Issues

These runtime bugs were identified during smoke testing and need to be fixed:

1. **BSON.ObjectId JSON serialization** — `GET /api/v1/tags` returns 500. Tags catalog documents contain `_id` as `BSON.ObjectId` which Jason can't encode. Fix: strip or convert `_id` in `ProfileController.tags_catalog/2`.

2. **Tuple unwrapping in count_documents** — `GET /api/v1/social/status` returns 500. `Repo.count_documents` returns `{:ok, count}` tuple but callers expect a plain integer. Affects `Social.get_matchmaker_count/1`, `Social.is_matchmaking_active?/1`, `Social.can_matchmake?/2`, and `Social.has_matchmaker_relationship?/2`. Fix: unwrap the tuple in `Repo.count_documents` or in each caller.

3. **Seed user profiles return null** — `GET /api/v1/profile` returns `{profile: null}` for seed users. The seed script stores `user_id` as a string (`to_string(user["_id"])`), but `Profiles.get_profile/1` queries with `BSON.ObjectId`. Type mismatch causes lookup to fail. Fix: align the query type or seed storage.

## Project Management

- **lore/** — Architecture decision records and implementation summaries. Add entries after completing significant features. Naming: `NNN-description.md`.
- **Planning workflow** — When entering plan mode, write a lore file summarizing the plan before implementation.
