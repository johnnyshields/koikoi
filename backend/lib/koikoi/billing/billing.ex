defmodule Koikoi.Billing do
  @moduledoc """
  The Billing context handles subscriptions, credit purchases,
  and Stripe integration for the Koikoi matchmaking app.
  """

  alias Koikoi.Repo
  alias Koikoi.Accounts

  @users_collection "users"
  @credit_transactions_collection "credit_transactions"

  @subscription_plans [
    %{
      id: "basic",
      name_ja: "ベーシックプラン",
      name_en: "Basic Plan",
      price_jpy: 3980,
      features_ja: ["メッセージ無制限", "いいね50回/日"],
      features_en: ["Unlimited messaging", "50 likes/day"]
    },
    %{
      id: "vip",
      name_ja: "VIPプラン",
      name_en: "VIP Plan",
      price_jpy: 6980,
      features_ja: ["メッセージ無制限", "いいね無制限", "既読確認", "優先マッチング", "毎月100クレジット"],
      features_en: [
        "Unlimited messaging",
        "Unlimited likes",
        "Read receipts",
        "Priority matching",
        "100 credits/month"
      ]
    }
  ]

  @credit_packages [
    %{id: "small", credits: 100, price_jpy: 980, name_ja: "100クレジット", name_en: "100 Credits"},
    %{
      id: "medium",
      credits: 300,
      price_jpy: 2480,
      name_ja: "300クレジット",
      name_en: "300 Credits",
      popular: true
    },
    %{
      id: "large",
      credits: 500,
      price_jpy: 3980,
      name_ja: "500クレジット",
      name_en: "500 Credits",
      best_value: true
    }
  ]

  # --- Plan & Package Info ---

  def get_plans, do: @subscription_plans

  def get_credit_packages, do: @credit_packages

  # --- Subscriptions ---

  def create_checkout_session(user_id, plan) when plan in ["basic", "vip"] do
    with user when not is_nil(user) <- Accounts.get_user(user_id),
         {:ok, customer_id} <- ensure_stripe_customer(user),
         price_id <- get_price_id(plan) do
      params = %{
        customer: customer_id,
        mode: "subscription",
        line_items: [%{price: price_id, quantity: 1}],
        success_url: success_url("/billing/subscription-success"),
        cancel_url: cancel_url("/billing"),
        metadata: %{user_id: to_string(user["_id"]), plan: plan}
      }

      case stripe_create_checkout_session(params) do
        {:ok, session} ->
          {:ok, %{checkout_url: session.url, session_id: session.id}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def create_checkout_session(_user_id, _plan), do: {:error, "invalid_plan"}

  def handle_checkout_completed(%{"mode" => "subscription"} = session) do
    user_id = get_in(session, ["metadata", "user_id"])
    plan = get_in(session, ["metadata", "plan"])
    subscription_id = session["subscription"]

    if user_id && plan do
      oid = to_object_id(user_id)

      Repo.update_one(
        @users_collection,
        %{_id: oid},
        %{
          "$set" => %{
            "subscription.plan" => plan,
            "subscription.stripe_subscription_id" => subscription_id,
            "updated_at" => DateTime.utc_now()
          }
        }
      )

      :ok
    else
      {:error, "missing_metadata"}
    end
  end

  def handle_checkout_completed(%{"mode" => "payment"} = session) do
    user_id = get_in(session, ["metadata", "user_id"])
    package_id = get_in(session, ["metadata", "package"])
    session_id = session["id"]

    if user_id && package_id do
      package = Enum.find(@credit_packages, &(&1.id == package_id))

      if package do
        add_credits(
          user_id,
          package.credits,
          "purchase",
          "Credit purchase: #{package.name_en}",
          %{
            stripe_session_id: session_id,
            package: package_id
          }
        )
      else
        {:error, "invalid_package"}
      end
    else
      {:error, "missing_metadata"}
    end
  end

  def handle_checkout_completed(_session), do: :ok

  def handle_subscription_updated(subscription) do
    customer_id = subscription["customer"]

    case find_user_by_stripe_customer(customer_id) do
      nil ->
        {:error, :not_found}

      user ->
        plan = resolve_plan_from_subscription(subscription)
        status = subscription["status"]
        current_period_end = subscription["current_period_end"]

        expires_at =
          if current_period_end do
            DateTime.from_unix!(current_period_end)
          else
            nil
          end

        updates =
          if status in ["active", "trialing"] do
            %{
              "subscription.plan" => plan,
              "subscription.expires_at" => expires_at,
              "subscription.stripe_subscription_id" => subscription["id"],
              "updated_at" => DateTime.utc_now()
            }
          else
            %{
              "subscription.plan" => "free",
              "subscription.expires_at" => nil,
              "updated_at" => DateTime.utc_now()
            }
          end

        Repo.update_one(@users_collection, %{_id: user["_id"]}, %{"$set" => updates})
        :ok
    end
  end

  def handle_subscription_deleted(subscription) do
    customer_id = subscription["customer"]

    case find_user_by_stripe_customer(customer_id) do
      nil ->
        {:error, :not_found}

      user ->
        Repo.update_one(
          @users_collection,
          %{_id: user["_id"]},
          %{
            "$set" => %{
              "subscription.plan" => "free",
              "subscription.expires_at" => nil,
              "subscription.stripe_subscription_id" => nil,
              "updated_at" => DateTime.utc_now()
            }
          }
        )

        :ok
    end
  end

  def get_subscription(user_id) do
    case Accounts.get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        subscription = user["subscription"] || %{"plan" => "free", "expires_at" => nil}
        {:ok, subscription}
    end
  end

  def cancel_subscription(user_id) do
    case Accounts.get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        subscription = user["subscription"] || %{}
        stripe_sub_id = subscription["stripe_subscription_id"]

        cond do
          subscription["plan"] in [nil, "free"] ->
            {:error, "no_active_subscription"}

          is_nil(stripe_sub_id) ->
            # No Stripe subscription ID, just revert locally
            Repo.update_one(
              @users_collection,
              %{_id: user["_id"]},
              %{
                "$set" => %{
                  "subscription.plan" => "free",
                  "subscription.expires_at" => nil,
                  "subscription.stripe_subscription_id" => nil,
                  "updated_at" => DateTime.utc_now()
                }
              }
            )

            {:ok, %{status: "canceled"}}

          true ->
            case stripe_cancel_subscription(stripe_sub_id) do
              {:ok, sub} -> {:ok, %{status: sub.status, cancel_at_period_end: true}}
              {:error, reason} -> {:error, reason}
            end
        end
    end
  end

  def has_active_subscription?(user_id) do
    case Accounts.get_user(user_id) do
      nil ->
        false

      user ->
        subscription = user["subscription"] || %{}
        plan = subscription["plan"]
        expires_at = subscription["expires_at"]

        plan not in [nil, "free"] &&
          (is_nil(expires_at) || DateTime.compare(expires_at, DateTime.utc_now()) == :gt)
    end
  end

  # --- Credits ---

  def create_credit_purchase_session(user_id, package_id)
      when package_id in ["small", "medium", "large"] do
    package = Enum.find(@credit_packages, &(&1.id == package_id))

    with user when not is_nil(user) <- Accounts.get_user(user_id),
         {:ok, customer_id} <- ensure_stripe_customer(user) do
      params = %{
        customer: customer_id,
        mode: "payment",
        line_items: [
          %{
            price_data: %{
              currency: "jpy",
              unit_amount: package.price_jpy,
              product_data: %{name: package.name_en}
            },
            quantity: 1
          }
        ],
        success_url: success_url("/billing/credits-success"),
        cancel_url: cancel_url("/billing"),
        metadata: %{user_id: to_string(user["_id"]), package: package_id}
      }

      case stripe_create_checkout_session(params) do
        {:ok, session} ->
          {:ok, %{checkout_url: session.url, session_id: session.id}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def create_credit_purchase_session(_user_id, _package), do: {:error, "invalid_package"}

  def add_credits(user_id, amount, type, description, metadata \\ %{})
      when is_integer(amount) and amount > 0 do
    oid = to_object_id(user_id)

    case Accounts.get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        current_balance = user["credits"] || 0
        new_balance = current_balance + amount
        now = DateTime.utc_now()

        transaction = %{
          user_id: oid,
          type: type,
          amount: amount,
          balance_after: new_balance,
          description: description,
          metadata: metadata,
          inserted_at: now
        }

        with {:ok, _} <- Repo.insert_one(@credit_transactions_collection, transaction),
             {:ok, _} <-
               Repo.update_one(
                 @users_collection,
                 %{_id: oid},
                 %{"$set" => %{credits: new_balance, updated_at: now}}
               ) do
          {:ok, %{balance: new_balance, transaction: transaction}}
        end
    end
  end

  def spend_credits(user_id, amount, description, metadata \\ %{})
      when is_integer(amount) and amount > 0 do
    oid = to_object_id(user_id)

    case Accounts.get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        current_balance = user["credits"] || 0

        if current_balance < amount do
          {:error, :insufficient_credits}
        else
          new_balance = current_balance - amount
          now = DateTime.utc_now()

          transaction = %{
            user_id: oid,
            type: "spend",
            amount: -amount,
            balance_after: new_balance,
            description: description,
            metadata: metadata,
            inserted_at: now
          }

          with {:ok, _} <- Repo.insert_one(@credit_transactions_collection, transaction),
               {:ok, _} <-
                 Repo.update_one(
                   @users_collection,
                   %{_id: oid},
                   %{"$set" => %{credits: new_balance, updated_at: now}}
                 ) do
            {:ok, %{balance: new_balance, transaction: transaction}}
          end
        end
    end
  end

  def get_credit_balance(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user["credits"] || 0}
    end
  end

  def list_transactions(user_id, opts \\ []) do
    oid = to_object_id(user_id)
    page = Keyword.get(opts, :page, 1)
    limit = Keyword.get(opts, :limit, 20) |> min(100)
    type_filter = Keyword.get(opts, :type)
    skip = (page - 1) * limit

    filter =
      %{user_id: oid}
      |> maybe_add_type_filter(type_filter)

    transactions =
      Repo.find(@credit_transactions_collection, filter,
        sort: %{inserted_at: -1},
        skip: skip,
        limit: limit
      )
      |> Enum.to_list()

    {:ok, total} = Repo.count_documents(@credit_transactions_collection, filter)

    total_pages =
      if total == 0, do: 0, else: ceil(total / limit)

    {:ok,
     %{
       transactions: transactions,
       page: page,
       limit: limit,
       total: total,
       total_pages: total_pages
     }}
  end

  # --- Stripe Helpers (safe for dev without Stripe configured) ---

  defp stripe_configured? do
    api_key = Application.get_env(:stripity_stripe, :api_key, "")
    api_key != "" && !String.starts_with?(api_key, "sk_test_placeholder")
  end

  defp stripe_create_checkout_session(params) do
    if stripe_configured?() do
      Stripe.Checkout.Session.create(params)
    else
      mock_session_id =
        "cs_mock_" <> (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower))

      {:ok,
       %{
         id: mock_session_id,
         url: "https://checkout.stripe.com/mock/#{mock_session_id}"
       }}
    end
  end

  defp stripe_cancel_subscription(subscription_id) do
    if stripe_configured?() do
      Stripe.Subscription.update(subscription_id, %{cancel_at_period_end: true})
    else
      {:ok, %{id: subscription_id, status: "active", cancel_at_period_end: true}}
    end
  end

  defp ensure_stripe_customer(user) do
    case user["stripe_customer_id"] do
      nil ->
        if stripe_configured?() do
          case Stripe.Customer.create(%{
                 metadata: %{koikoi_user_id: to_string(user["_id"])}
               }) do
            {:ok, customer} ->
              Repo.update_one(
                @users_collection,
                %{_id: user["_id"]},
                %{
                  "$set" => %{
                    stripe_customer_id: customer.id,
                    updated_at: DateTime.utc_now()
                  }
                }
              )

              {:ok, customer.id}

            {:error, reason} ->
              {:error, reason}
          end
        else
          mock_id = "cus_mock_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))

          Repo.update_one(
            @users_collection,
            %{_id: user["_id"]},
            %{
              "$set" => %{
                stripe_customer_id: mock_id,
                updated_at: DateTime.utc_now()
              }
            }
          )

          {:ok, mock_id}
        end

      customer_id ->
        {:ok, customer_id}
    end
  end

  defp find_user_by_stripe_customer(customer_id) do
    Repo.find_one(@users_collection, %{stripe_customer_id: customer_id})
  end

  defp get_price_id("basic"),
    do: Application.get_env(:koikoi, :stripe, [])[:basic_price_id] || "price_basic_placeholder"

  defp get_price_id("vip"),
    do: Application.get_env(:koikoi, :stripe, [])[:vip_price_id] || "price_vip_placeholder"

  defp resolve_plan_from_subscription(subscription) do
    items = get_in(subscription, ["items", "data"]) || []

    basic_price_id = get_price_id("basic")
    vip_price_id = get_price_id("vip")

    cond do
      Enum.any?(items, fn item -> get_in(item, ["price", "id"]) == vip_price_id end) -> "vip"
      Enum.any?(items, fn item -> get_in(item, ["price", "id"]) == basic_price_id end) -> "basic"
      true -> "basic"
    end
  end

  defp success_url(path) do
    frontend_url = Application.get_env(:koikoi, :frontend_url, "http://localhost:5173")
    frontend_url <> path
  end

  defp cancel_url(path) do
    frontend_url = Application.get_env(:koikoi, :frontend_url, "http://localhost:5173")
    frontend_url <> path
  end

  defp maybe_add_type_filter(filter, nil), do: filter
  defp maybe_add_type_filter(filter, ""), do: filter

  defp maybe_add_type_filter(filter, type) when type in ["purchase", "spend", "bonus", "refund"],
    do: Map.put(filter, :type, type)

  defp maybe_add_type_filter(filter, _), do: filter

  defp to_object_id(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, oid} -> oid
      :error -> id
    end
  end

  defp to_object_id(id), do: id
end
