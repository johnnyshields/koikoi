defmodule KoikoiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :koikoi

  socket "/socket", KoikoiWeb.UserSocket,
    websocket: [check_origin: false],
    longpoll: false

  # Serve uploaded files (photos, etc.)
  plug Plug.Static,
    at: "/uploads",
    from: {:koikoi, "priv/static/uploads"},
    gzip: false

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :koikoi,
    gzip: not code_reloading?,
    only: KoikoiWeb.static_paths(),
    raise_on_missing_only: code_reloading?

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    body_reader: {KoikoiWeb.Plugs.StripeWebhook, :read_body, []},
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # CORS - must be before the router
  plug Corsica,
    origins: ["http://localhost:5173", "http://localhost:3000"],
    allow_headers: ["content-type", "authorization", "accept-language"],
    allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_credentials: true

  plug KoikoiWeb.Router
end
