defmodule KoikoiWeb.BillingController do
  use KoikoiWeb, :controller

  alias Koikoi.Billing

  action_fallback KoikoiWeb.FallbackController

  # GET /api/v1/billing/plans
  def list_plans(conn, _params) do
    plans = Billing.get_plans()
    json(conn, %{plans: plans})
  end

  # GET /api/v1/billing/credit-packages
  def list_credit_packages(conn, _params) do
    packages = Billing.get_credit_packages()
    json(conn, %{packages: packages})
  end

  # GET /api/v1/billing/subscription
  def get_subscription(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, subscription} <- Billing.get_subscription(to_string(user["_id"])) do
      json(conn, %{subscription: subscription})
    end
  end

  # POST /api/v1/billing/subscribe
  def create_subscription_checkout(conn, %{"plan" => plan}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, result} <- Billing.create_checkout_session(to_string(user["_id"]), plan) do
      json(conn, %{checkout_url: result.checkout_url, session_id: result.session_id})
    end
  end

  def create_subscription_checkout(_conn, _params), do: {:error, "plan_required"}

  # POST /api/v1/billing/cancel-subscription
  def cancel_subscription(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, result} <- Billing.cancel_subscription(to_string(user["_id"])) do
      json(conn, %{status: result.status})
    end
  end

  # POST /api/v1/billing/purchase-credits
  def create_credit_purchase_checkout(conn, %{"package" => package}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, result} <- Billing.create_credit_purchase_session(to_string(user["_id"]), package) do
      json(conn, %{checkout_url: result.checkout_url, session_id: result.session_id})
    end
  end

  def create_credit_purchase_checkout(_conn, _params), do: {:error, "package_required"}

  # GET /api/v1/billing/credits
  def get_credits(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, balance} <- Billing.get_credit_balance(to_string(user["_id"])) do
      json(conn, %{credits: balance})
    end
  end

  # GET /api/v1/billing/transactions
  def list_transactions(conn, params) do
    user = Guardian.Plug.current_resource(conn)

    opts = [
      page: parse_int(params["page"], 1),
      limit: parse_int(params["limit"], 20),
      type: params["type"]
    ]

    with {:ok, result} <- Billing.list_transactions(to_string(user["_id"]), opts) do
      transactions =
        Enum.map(result.transactions, fn tx ->
          %{
            id: to_string(tx["_id"]),
            type: tx["type"],
            amount: tx["amount"],
            balance_after: tx["balance_after"],
            description: tx["description"],
            metadata: tx["metadata"],
            inserted_at: tx["inserted_at"]
          }
        end)

      json(conn, %{
        transactions: transactions,
        page: result.page,
        limit: result.limit,
        total: result.total,
        total_pages: result.total_pages
      })
    end
  end

  # POST /api/v1/billing/webhook
  def webhook(conn, _params) do
    raw_body = conn.private[:raw_body] || ""
    signature = List.first(get_req_header(conn, "stripe-signature")) || ""
    webhook_secret = Application.get_env(:koikoi, :stripe, [])[:webhook_secret]

    if webhook_secret && webhook_secret != "whsec_placeholder" do
      case Stripe.Webhook.construct_event(raw_body, signature, webhook_secret) do
        {:ok, event} ->
          handle_stripe_event(event)
          send_resp(conn, 200, "ok")

        {:error, _reason} ->
          send_resp(conn, 400, "invalid_signature")
      end
    else
      # Dev mode: parse body directly without signature verification
      case Jason.decode(raw_body) do
        {:ok, event} ->
          handle_stripe_event(event)
          send_resp(conn, 200, "ok")

        {:error, _} ->
          send_resp(conn, 400, "invalid_payload")
      end
    end
  end

  # --- Private ---

  defp handle_stripe_event(%{
         "type" => "checkout.session.completed",
         "data" => %{"object" => session}
       }) do
    Billing.handle_checkout_completed(session)
  end

  defp handle_stripe_event(%{
         "type" => "customer.subscription.updated",
         "data" => %{"object" => sub}
       }) do
    Billing.handle_subscription_updated(sub)
  end

  defp handle_stripe_event(%{
         "type" => "customer.subscription.deleted",
         "data" => %{"object" => sub}
       }) do
    Billing.handle_subscription_deleted(sub)
  end

  defp handle_stripe_event(%{
         "type" => "customer.subscription.created",
         "data" => %{"object" => sub}
       }) do
    Billing.handle_subscription_updated(sub)
  end

  defp handle_stripe_event(_event), do: :ok

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val) and val > 0, do: val
  defp parse_int(_, default), do: default
end
