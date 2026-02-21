# 001 - Koikoi Initial Architecture

## Date: 2026-02-21

## Summary

Koikoi is a Japanese matchmaking dating app where friends act as matchmakers ("omiai" style).
Instead of swiping directly, matchmakers see pairs of their friends and rate compatibility.
The system aggregates weighted ratings and creates matches when confidence thresholds are met.

## Tech Stack

- **Backend**: Elixir/Phoenix (API-only) with MongoDB via mongodb_driver/mongodb_ecto
- **Frontend**: React + TypeScript + Vite + TailwindCSS
- **Auth**: Guardian (JWT) + Argon2
- **Real-time**: Phoenix Channels (WebSocket)
- **i18n**: Gettext (backend) + i18next (frontend), Japanese primary

## Key Architectural Decisions

1. **Monorepo**: `backend/` (Phoenix) + `frontend/` (React) in single repo
2. **Separate users/profiles collections**: Auth data isolated from profile data for security
3. **Canonical pair ordering**: Always person_a_id < person_b_id to prevent duplicate pairs
4. **Rule-based AI matchmaker first**: Deterministic, testable, no LLM cost. Enhancement later.
5. **GenServer-based background jobs**: No Oban (requires PostgreSQL). Custom workers with MongoDB persistence.
6. **JWT with refresh token rotation**: 15-min access, 30-day refresh, single-use rotation.
7. **MongoDB on Windows host**: WSL2 connects via gateway IP (`ip route show default`)

## Build Phases

1. **Phase 1**: Foundation (Backend skeleton, Frontend scaffold, Database/Seeds)
2. **Phase 2**: Profiles + Social Graph
3. **Phase 3**: Matchmaking Engine (Card Dealer, Scorer, Aggregator)
4. **Phase 4**: AI Matchmaker (rule-based compatibility analysis)
5. **Phase 5**: Chat + Notifications (Phoenix Channels)
6. **Phase 6**: Billing + Polish (Stripe integration)

## Card-Dealing Algorithm

Pair selection scores based on: tag overlap (30%), profile completeness (20%),
cold pair bonus (20%), matchmaker familiarity (20%), freshness penalty (-10%).

Match threshold: 3+ human ratings, score >= 0.70, 2+ strong ratings (>=4).
Cold start: 2 human + 1 AI, score >= 0.75, 2+ strong ratings.

## Database Collections

users, profiles, connections, matchmaking_sessions, matches,
conversations, messages, notifications, tags_catalog,
phone_verifications, credit_transactions
