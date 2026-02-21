# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :koikoi,
  generators: [timestamp_type: :utc_datetime]

# Guardian JWT configuration
config :koikoi, Koikoi.Accounts.Guardian,
  issuer: "koikoi",
  secret_key: "dev-secret-key-change-in-production-must-be-at-least-32-chars-long!!",
  ttl: {15, :minutes}

# Configure the endpoint
config :koikoi, KoikoiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: KoikoiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Koikoi.PubSub,
  live_view: [signing_salt: "cJxD4iVv"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Stripe configuration
config :stripity_stripe,
  api_key: System.get_env("STRIPE_SECRET_KEY") || "sk_test_placeholder"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
