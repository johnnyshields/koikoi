# 003 - Matchmaking Engine

## Date: 2026-02-21

## Summary

Core matchmaking system: card dealing, compatibility scoring, and match aggregation. This is the heart of the product — the mechanism by which matchmaker friends rate pairs and the system creates matches.

## Architecture

### Card Dealer (`Koikoi.Matching.CardDealer`)

The card dealer selects which pairs to show a matchmaker. It's designed to maximize useful signal while keeping the matchmaker engaged.

**Pair generation pipeline:**
1. Get matchable user IDs via `Social.get_matchable_users/1` (users who accepted this person as matchmaker)
2. Generate all canonical pairs (person_a_id < person_b_id) that cross gender preferences
3. Filter out: pairs already rated by this matchmaker, pairs with active/completed matches
4. Score remaining pairs for presentation priority
5. Return top 10 sorted by score

**Scoring formula** (each factor 0.0-1.0, then weighted):
- **Tag overlap (30%)** — Jaccard similarity coefficient of both profiles' tag sets. Higher overlap suggests more to talk about
- **Profile completeness (20%)** — Average of both profiles' completeness scores. Complete profiles give matchmakers more to work with
- **Cold pair bonus (20%)** — Inverse of existing rating count. Ensures new users and under-rated pairs get exposure
- **Matchmaker familiarity (20%)** — Based on trust tier. Both inner_circle = 2.0x, one inner = 1.5x, both friends = 1.0x. Matchmakers rate more accurately for people they know well
- **Freshness penalty (-10%)** — Pairs shown 10+ times across all matchmakers without producing a match get deprioritized

### Compatibility Scorer (`Koikoi.Matching.CompatibilityScorer`)

Aggregates multiple matchmaker ratings into a single compatibility score.

**Weight calculation per rating:**
```
weight = confidence_mult × tier_mult × recency_mult × ai_mult
```

| Factor | Values |
|--------|--------|
| Confidence | low=0.5, medium=1.0, high=1.5 |
| Tier | both_inner_circle=2.0, one_inner=1.5, friends=1.0 |
| Recency | ≤7d=1.0, ≤30d=0.9, ≤90d=0.8, >90d=0.6 |
| AI | human=1.0, AI=0.3 |

**Final score** = sum(rating_normalized × weight) / sum(weight), where rating_normalized = (rating - 1) / 4 to map 1-5 → 0-1.

### Match Aggregator (`Koikoi.Matching.MatchAggregator`)

Triggers after each rating submission. Checks if the pair crosses match threshold.

**Normal threshold:**
- 3+ human ratings
- Weighted compatibility score ≥ 0.70
- 2+ strong ratings (≥4 stars)

**Cold start threshold** (when AI ratings exist):
- 2 human + 1 AI rating minimum
- Score ≥ 0.75 (higher bar since AI signal is weaker)
- 2+ strong ratings

**Match lifecycle:**
1. Threshold crossed → match created with status `pending_intro`
2. Both parties notified with signal summary (shared tags, top matchmaker notes, strong rating count)
3. 72-hour window to accept or decline
4. Both accept → status becomes `chatting`, conversation auto-created
5. Either declines → status becomes `declined`
6. Timer expires → status becomes `expired`

**MatchExpirationWorker** — GenServer that runs every 5 minutes, queries for matches with `status: "pending_intro"` and `expires_at < now`, updates them to `expired`.

## Frontend UX

The **CardDealingPage** is the signature interaction — matchmakers see a pair of profile cards side by side and rate their compatibility.

- **PairCard** shows both people: primary photo, nickname, age, location, and shared tags highlighted
- **SharedTagsBadge** — visual callout for overlapping interests ("二人とも: カフェ巡り, 写真")
- **RatingModal** — 1-5 stars, confidence selector (low/medium/high), optional free-text note
- Skip button for pairs the matchmaker doesn't feel qualified to rate

**MatchmakerDashboardPage** provides gamification:
- Total ratings submitted
- Successful matches created from their ratings
- Accuracy score (how often their high ratings led to matches)

## Design Decisions

1. **Canonical pair ordering** — `person_a_id < person_b_id` (string comparison) ensures each pair has exactly one representation across all collections. No duplicate pair checking needed.

2. **Signal summary on matches** — When a match is created, we snapshot the top signals (shared tags, best matchmaker notes, strong rating count) so the matched users see why they were paired. This adds trust and conversation starters.

3. **72-hour expiration** — Prevents indefinite pending states. Users who don't respond in time see the match expire, creating urgency without being pushy.

4. **Separate matchmaking_sessions from matches** — Sessions track individual ratings (the raw signal). Matches track aggregated results (the derived output). This separation allows re-scoring if the algorithm changes.
