# 005 - Chat, Notifications & Billing

## Date: 2026-02-21

## Summary

Real-time chat via Phoenix Channels, persisted notification system, and Stripe billing integration. These three systems were built in Phases 5-6 to complete the user journey from match → conversation → monetization.

## Chat System

### Backend (`Koikoi.Chat`)

**Collections:**
- `conversations` — created when both parties accept a match introduction. Fields: `match_id`, `participants` (array of user_id strings), `last_message`, `last_message_at`, timestamps
- `messages` — individual messages. Fields: `conversation_id`, `sender_id`, `content`, `read`, timestamps

**Access control:**
- Only participants of a conversation can read/send messages
- Men require an active paid subscription (`basic` or `vip`) to send messages
- Women can message freely
- Checked via `Koikoi.Billing.has_active_subscription?/1`

**Endpoints:**
- `GET /conversations` — list user's conversations with last message preview
- `GET /conversations/:id` — single conversation detail
- `GET /conversations/:id/messages` — paginated message history
- `POST /conversations/:id/messages` — send message (subscription check for men)
- `POST /conversations/:id/read` — mark conversation as read
- `GET /chat/unread-count` — total unread messages across all conversations

### WebSocket (`ChatChannel`)

Joins topic `chat:{conversation_id}` with auth check (must be participant).

**Events:**
- `new_message` — broadcast when a message is sent. Payload: message document with sender info
- `typing` — broadcast typing indicator. Payload: `{user_id: string}`
- `mark_read` — broadcast when messages are marked read. Payload: `{user_id: string, conversation_id: string}`

### Frontend
- **ConversationsPage** — list sorted by last message time, shows unread badge per conversation
- **ChatPage** — real-time message display with auto-scroll, typing indicator, message grouping by sender/time, input with send button

## Notification System

### Backend (`Koikoi.Notifications`)

**Collection:** `notifications` — Fields: `user_id`, `type`, `title`, `body`, `data` (arbitrary metadata), `read`, timestamps

**Notification types:**
- `new_match` — when a match crosses threshold
- `message` — new chat message (for users not currently in the conversation)
- `matchmaker_request` — someone invited you as a matchmaker
- `matchmaker_success` — a pair you rated became a match
- `match_expired` — pending introduction timed out

**Delivery:** Uses Phoenix PubSub to broadcast to `notification:{user_id}` topic. The `NotificationChannel` subscribes to this topic on join.

**Endpoints:**
- `GET /notifications` — paginated list
- `POST /notifications/:id/read` — mark single as read
- `POST /notifications/read-all` — mark all as read
- `GET /notifications/unread-count` — count for badge display

### WebSocket (`NotificationChannel`)

Joins topic `notifications:{user_id}`. Subscribes to PubSub and forwards `new_notification` events to the client.

### UserSocket

Authenticates via `token` parameter in WebSocket connection params. Verifies JWT and assigns `user_id` to socket.

### Frontend
- **NotificationsPage** — full notification list with type-based icons and formatting
- **NotificationBell** — header component showing unread count badge, used in AppLayout
- **useSocket** — singleton Phoenix socket connection, auto-connects when auth token exists
- **useChannel** — joins a channel, registers event handlers, auto-leaves on unmount

## Billing System

### Backend (`Koikoi.Billing`)

**Stripe integration via `stripity_stripe`:**
- Creates Stripe customers on first subscription/purchase
- Stores `stripe_customer_id` on user document

**Plans:**
| Plan | Price | Features |
|------|-------|----------|
| Basic | ¥3,980/mo | Messaging unlock for men |
| VIP | ¥6,980/mo | Read receipts, priority matching, premium badge |

**Credit packages:**
| Package | Price | Credits |
|---------|-------|---------|
| Small | ¥480 | 100 |
| Medium | ¥1,280 | 300 |
| Large | ¥1,980 | 500 |

**Webhook handling:**
- `StripeWebhook` plug captures raw request body before JSON parsing (required for Stripe signature verification)
- Handles: `checkout.session.completed` (activate subscription or add credits), `customer.subscription.updated` (plan changes), `customer.subscription.deleted` (cancellation)

**Credit ledger:** `credit_transactions` collection tracks all credit movements with `type` (purchase/spend), `amount`, `description`, `balance_after`.

**Endpoints:**
- `GET /billing/plans` — available subscription plans
- `GET /billing/credit-packages` — available credit packages
- `GET /billing/subscription` — current subscription status
- `POST /billing/subscribe` — create Stripe checkout session for subscription
- `POST /billing/cancel-subscription` — cancel via Stripe API
- `POST /billing/purchase-credits` — create checkout session for credits
- `GET /billing/credits` — current credit balance
- `GET /billing/transactions` — credit transaction history
- `POST /billing/webhook` — Stripe webhook (public, no auth, signature verified)

### Frontend
- **SubscriptionPage** — plan comparison cards, current plan highlight, subscribe/cancel buttons
- **CreditsPage** — balance display, package cards, transaction history table
- **PaymentSuccessPage** — post-checkout confirmation with redirect
- **PremiumBadge** — small badge component for VIP users
- **SubscriptionBanner** — upsell prompt shown to free-tier men when they try to message

## Design Decisions

1. **Conversation creation tied to match acceptance** — conversations aren't created until both parties accept the introduction. This prevents empty conversations and ensures both users are opted in.

2. **Gender-based billing model** — follows Japanese dating app convention (Pairs, Omiai, etc.) where men pay to message and women use the app free. Implemented as a middleware check in `Chat.send_message/3`.

3. **PubSub for notifications** — rather than polling, notifications are pushed in real-time via Phoenix PubSub → NotificationChannel → WebSocket. Persisted to MongoDB for history/catch-up.

4. **Stripe Checkout (hosted)** — uses Stripe's hosted checkout page rather than embedded elements. Simpler to implement, handles PCI compliance, supports Japanese payment methods out of the box.

5. **Raw body capture for webhooks** — the `StripeWebhook` plug intercepts the request body before `Plug.Parsers` processes it, storing it in `conn.assigns[:raw_body]` for Stripe signature verification.
