# 008 - Chat-Centered Pivot Plan

Date: 2026-02-22

## Summary

Plan for pivoting Koikoi from a dashboard/page-based matchmaking model to a chat-centered model. The current app has separate pages for friends, matchmakers, card-dealing, matches, and chat. The new model puts chats (DMs, group chats, shokai introductions) at the center.

## Build Order

1. **DMs between friends** (foundation) -- allow any two friends to DM
2. **Group chats** (differentiator) -- group + goukon (time-limited group) chats
3. **Shokai cards** (core innovation) -- matchmaker-created introduction cards that live in chat
4. **Cleanup** -- remove deprecated pages, add Instagram link, update i18n

## Implementation Strategy

Two-teammate parallel build (backend + frontend). Zero file overlap between workers.

### Backend Worker
- Phase 1: `Social.are_friends?/2`, `Chat.get_or_create_dm/2`, DM endpoint, updated serialization
- Phase 2: Group/goukon creation, member management, system messages, multi-participant notifications
- Phase 3: New `Shokai` module, shokai controller, expiration worker, `quick_rate` in matching

### Frontend Worker
- Phase 1: Updated types + Conversation type field, DM creation API/store, 3-tab nav (Chats/Contacts/Profile), ConversationsPage as home, new ContactsPage
- Phase 2: Group creation/settings pages, MemberPicker component, GroupAvatar, system message rendering
- Phase 3: Shokai API/store, ShokaiCardBubble component, create/detail pages, pinned shokais in chat list

### Supervisor
- Defines API contracts upfront
- Phase 4 cleanup: remove deprecated pages, Instagram link, i18n updates
- Harden, lint, test, commit

## Key API Contracts

- `POST /api/v1/conversations/dm` -- create/get DM with friend
- `POST /api/v1/conversations/group` -- create group chat
- `POST /api/v1/conversations/goukon` -- create time-limited group
- `POST /api/v1/conversations/:id/members` -- add members
- `DELETE /api/v1/conversations/:id/members/:user_id` -- remove member
- `POST /api/v1/conversations/:id/leave` -- leave group
- `PUT /api/v1/conversations/:id` -- update group
- `GET /api/v1/conversations/:id/members` -- list members
- `POST /api/v1/shokai` -- create introduction
- `GET /api/v1/shokai/pending` -- list pending for user
- `GET /api/v1/shokai/sent` -- list sent by matchmaker
- `GET /api/v1/shokai/suggestions` -- get suggested pairs
- `GET /api/v1/shokai/:id` -- get detail
- `POST /api/v1/shokai/:id/respond` -- accept/decline

## Design Decisions

1. **Conversation type field** -- add `type` to existing conversations collection rather than separate collections
2. **Canonical participant ordering** -- sort participant OIDs for DM dedup queries
3. **System messages** -- `message_type: "system"` with `sender_id: nil` for join/leave/created events
4. **Shokai as separate collection** -- `shokai_cards` collection, not embedded in conversations, because they have independent lifecycle (expiry, responses from both parties)
5. **Reuse CardDealer scoring** -- shokai suggestions reuse the existing pair scoring from `Matching.CardDealer`
6. **3-tab nav** -- Chats (home) / Contacts / Profile replaces the 5-tab layout
