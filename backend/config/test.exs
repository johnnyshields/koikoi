import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :koikoi, KoikoiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "4d0nep0SQPDXLI1ThCKArSTD7rImG41xpUONcAA5lMKNwnxS2NGDSOEp2x8bPnCk",
  server: false

# MongoDB configuration (Windows host via WSL2 gateway)
config :koikoi, Koikoi.Repo,
  url: "mongodb://#{System.get_env("MONGODB_HOST", "172.29.208.1")}:27017/koikoi_test",
  pool_size: 5

# Stripe test configuration
config :koikoi, :stripe,
  webhook_secret: "whsec_placeholder",
  basic_price_id: "price_basic_placeholder",
  vip_price_id: "price_vip_placeholder"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
