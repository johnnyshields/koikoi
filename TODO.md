# Koikoi TODO

## Product Direction: Shokai (紹介) Pivot

Reframe from "friends rate pairs" to **"friends introduce friends they vouch for."**
No existing app digitizes the shokai social graph. Every competitor is stranger-to-stranger matching that builds trust after the fact. Koikoi should be trust-first.

### Core: Shokai Flow
- [ ] Primary action is "I think my friend A would get along with my friend B" (not just rating)
- [ ] Both parties get a soft notification: "Your friend [Name] thinks you'd get along with someone. Want to see their profile?"
- [ ] Introducer's reputation is at stake -- social accountability built into the system
- [ ] Weighted matchmaker credibility: inner_circle introductions count more than distant acquaintances
- [ ] Successful matchmakers gain reputation over time

### QR Code Social Graph Building
- [ ] Users share a Koikoi QR code at events, nomikai, goukon
- [ ] Scanning adds someone to your social graph (as potential matchmaker or matchable friend, not as romantic interest)
- [ ] Mirrors existing LINE QR exchange behavior -- culturally natural
- [ ] QR codes on printed materials for offline events / machikon integration

### Schedule & Date Logistics
- [ ] Users set availability windows ("free weekday evenings", "free this Saturday afternoon")
- [ ] When a shokai is accepted, app proposes meeting times based on mutual availability
- [ ] Location suggestions based on mutual geography (both in Shibuya? suggest Shibuya cafes)
- [ ] Zexy Enmusubi proved concierge date coordination is valued; Dine proved "skip chat, schedule date" works
- [ ] Consider "Odekake" style date proposals: user posts "coffee this weekend in Omotesando", introduced matches can opt in

### Group Introductions (Goukon-style)
- [ ] Matchmaker can introduce a group of friends to another group (not just 1-on-1)
- [ ] Lower pressure than 1-on-1, matches real Japanese dating behavior
- [ ] Coordinate group outing logistics within the app

### Trust & Safety
- [ ] Face-saving rejection: unaccepted introductions expire silently, no "rejected" notification
- [ ] Privacy-first contact exchange: communicate and meet without sharing LINE/phone until comfortable
- [ ] Identity verification (phone at minimum, My Number card marital status verification as stretch goal)
- [ ] Trust tiers (inner_circle/friends/verified/open) already built -- maps perfectly to uchi/soto dynamics

### Cold Start
- [ ] AI matchmaker (恋のキューピッド) fills the friend role for users with no connections yet
- [ ] 31 prefectures run government AI matchmaking programs -- concept is validated
- [ ] Bridge gap until organic social graph develops

### Monetization
- [ ] Women free, men pay -- culturally expected in Japan (Pairs, Tapple, Omiai all do this)
- [ ] Current model (basic 3,980/mo, VIP 6,980/mo) aligns with market (Pairs charges 3,900-4,100/mo)
- [ ] Free messaging for all users (differentiator vs Pairs where men pay to message)

### Cultural Fit
- [ ] Japanese-first design and language (already primary via i18n)
- [ ] Seasonal/event integration: hanami, matsuri, Christmas Eve date suggestions
- [ ] Slow progression expected: kokuhaku around 3rd date, not 1st
- [ ] No aggressive matching -- "gentle push" for the 69.3% who want to marry but haven't taken steps

## Existing Bugs (from smoke testing)
- [ ] `GET /api/v1/tags` returns 500 -- BSON.ObjectId not JSON-serializable in tags catalog
- [ ] `GET /api/v1/social/status` returns 500 -- `Repo.count_documents` returns tuple, callers expect integer
- [ ] `GET /api/v1/profile` returns null for seed users -- type mismatch (string vs BSON.ObjectId) in profile lookup

## Market Context
- Friend introductions = #2 way Japanese couples meet (20-27% of marriages)
- 77.2% of dating app users encountered trouble (scams, misrepresentation)
- 686K births in 2024 (record low), TFR 1.15
- Government spending 9.3B yen/yr on marriage support
- Pairs dominates at $77M/yr revenue, 20M+ users
- No major app combines social-graph trust with app convenience -- this is the gap

---

# Insta integration

- Koikoi should be a layer on top of Insta profiles.
