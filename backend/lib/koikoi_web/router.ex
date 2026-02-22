defmodule KoikoiWeb.Router do
  use KoikoiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug KoikoiWeb.Plugs.Locale
  end

  pipeline :authenticated do
    plug KoikoiWeb.Plugs.AuthPipeline
  end

  # Public routes
  scope "/api/v1", KoikoiWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
    post "/auth/refresh", AuthController, :refresh
    post "/auth/verify-phone", AuthController, :verify_phone
    post "/auth/request-code", AuthController, :request_verification_code

    # Tags catalog (public)
    get "/tags", ProfileController, :tags_catalog

    # Stripe webhook (needs raw body, no auth)
    post "/billing/webhook", BillingController, :webhook
  end

  # Authenticated routes
  scope "/api/v1", KoikoiWeb do
    pipe_through [:api, :authenticated]

    get "/auth/me", AuthController, :me
    post "/auth/logout", AuthController, :logout

    # Profiles
    get "/profile", ProfileController, :show
    put "/profile", ProfileController, :update
    get "/profiles/:user_id", ProfileController, :show_other
    post "/profile/photos", ProfileController, :upload_photo
    delete "/profile/photos/:photo_id", ProfileController, :delete_photo
    put "/profile/photos/reorder", ProfileController, :reorder_photos
    put "/profile/photos/:photo_id/primary", ProfileController, :set_primary
    post "/profile/tags", ProfileController, :add_tags
    delete "/profile/tags", ProfileController, :remove_tag

    # Friends - fixed paths before parameterized routes
    get "/friends/pending", SocialController, :list_pending_requests
    get "/friends", SocialController, :list_friends
    post "/friends/request", SocialController, :send_friend_request
    post "/friends/:connection_id/accept", SocialController, :accept_friend_request
    post "/friends/:connection_id/decline", SocialController, :decline_friend_request
    delete "/friends/:friend_id", SocialController, :remove_friend

    # Matchmakers - fixed paths before parameterized routes
    get "/matchmakers/subjects", SocialController, :list_matchmaker_subjects
    get "/matchmakers", SocialController, :list_matchmakers
    post "/matchmakers/invite", SocialController, :invite_matchmaker
    post "/matchmakers/:connection_id/accept", SocialController, :accept_matchmaker_invite
    post "/matchmakers/:connection_id/decline", SocialController, :decline_matchmaker_invite
    delete "/matchmakers/:matchmaker_id", SocialController, :remove_matchmaker

    # Trust tier
    put "/friends/:friend_id/trust-tier", SocialController, :update_trust_tier

    # Invites
    post "/invites/redeem", SocialController, :redeem_invite_code
    get "/invites/stats", SocialController, :get_invite_stats

    # Social status
    get "/social/status", SocialController, :matchmaking_status

    # Matching
    get "/matching/cards", MatchingController, :deal_cards
    post "/matching/rate", MatchingController, :submit_rating
    post "/matching/skip", MatchingController, :skip_pair
    get "/matching/stats", MatchingController, :matchmaker_stats

    # Matches
    get "/matches", MatchingController, :list_matches
    get "/matches/:match_id", MatchingController, :get_match
    post "/matches/:match_id/respond", MatchingController, :respond_to_match

    # AI Matchmaker
    get "/ai-matchmaker/persona", AiMatchmakerController, :persona
    get "/ai-matchmaker/analysis/:user_a_id/:user_b_id", AiMatchmakerController, :analyze
    post "/ai-matchmaker/trigger", AiMatchmakerController, :trigger_cold_start
    get "/ai-matchmaker/ratings", AiMatchmakerController, :ai_ratings

    # Chat - fixed paths before parameterized routes
    get "/chat/unread-count", ChatController, :unread_count
    post "/conversations/dm", ChatController, :create_dm
    post "/conversations/group", ChatController, :create_group
    post "/conversations/goukon", ChatController, :create_goukon
    get "/conversations", ChatController, :list_conversations
    # Parameterized conversation routes
    get "/conversations/:id", ChatController, :get_conversation
    get "/conversations/:id/messages", ChatController, :list_messages
    get "/conversations/:id/members", ChatController, :list_members
    post "/conversations/:id/messages", ChatController, :send_message
    post "/conversations/:id/members", ChatController, :add_members
    post "/conversations/:id/leave", ChatController, :leave_group
    post "/conversations/:id/read", ChatController, :mark_read
    put "/conversations/:id", ChatController, :update_group
    delete "/conversations/:id/members/:user_id", ChatController, :remove_member

    # Shokai - fixed paths before parameterized routes
    get "/shokai/pending", ShokaiController, :pending
    get "/shokai/sent", ShokaiController, :sent
    get "/shokai/suggestions", ShokaiController, :suggestions
    post "/shokai", ShokaiController, :create
    get "/shokai/:id", ShokaiController, :show
    post "/shokai/:id/respond", ShokaiController, :respond

    # Notifications - fixed paths before parameterized routes
    get "/notifications/unread-count", NotificationController, :unread_count
    post "/notifications/read-all", NotificationController, :mark_all_read
    get "/notifications", NotificationController, :list_notifications
    post "/notifications/:id/read", NotificationController, :mark_read

    # Billing
    get "/billing/plans", BillingController, :list_plans
    get "/billing/credit-packages", BillingController, :list_credit_packages
    get "/billing/subscription", BillingController, :get_subscription
    post "/billing/subscribe", BillingController, :create_subscription_checkout
    post "/billing/cancel-subscription", BillingController, :cancel_subscription
    post "/billing/purchase-credits", BillingController, :create_credit_purchase_checkout
    get "/billing/credits", BillingController, :get_credits
    get "/billing/transactions", BillingController, :list_transactions
  end

  # Health check
  scope "/api", KoikoiWeb do
    pipe_through :api
    get "/health", HealthController, :index
  end
end
