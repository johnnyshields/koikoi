defmodule KoikoiWeb.Plugs.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :koikoi,
    module: Koikoi.Accounts.Guardian,
    error_handler: KoikoiWeb.Plugs.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
