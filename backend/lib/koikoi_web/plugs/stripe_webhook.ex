defmodule KoikoiWeb.Plugs.StripeWebhook do
  @moduledoc """
  Custom body reader that caches the raw request body for Stripe webhook
  signature verification. Used as the :body_reader option for Plug.Parsers.

  Only caches the body for the Stripe webhook path to avoid memory overhead
  on other routes.
  """

  @webhook_path "/api/v1/billing/webhook"

  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {tag, body, conn} when tag in [:ok, :more] and conn.request_path == @webhook_path ->
        existing = conn.private[:raw_body] || ""
        conn = Plug.Conn.put_private(conn, :raw_body, existing <> body)
        {tag, body, conn}

      result ->
        result
    end
  end
end
