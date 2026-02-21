defmodule Koikoi.BillingTest do
  use ExUnit.Case, async: false

  alias Koikoi.Billing
  alias Koikoi.Repo

  @moduletag :mongodb

  @users_collection "users"
  @credit_transactions_collection "credit_transactions"

  setup do
    Repo.delete_many(@users_collection, %{})
    Repo.delete_many(@credit_transactions_collection, %{})
    :ok
  end

  defp create_test_user(overrides \\ %{}) do
    now = DateTime.utc_now()

    doc =
      Map.merge(
        %{
          phone_number: "+81901234567",
          password_hash: "fake_hash",
          gender: "male",
          subscription: %{plan: "free", expires_at: nil},
          credits: 0,
          inserted_at: now,
          updated_at: now
        },
        overrides
      )

    {:ok, result} = Repo.insert_one(@users_collection, doc)
    Repo.find_one(@users_collection, %{_id: result.inserted_id})
  end

  # --- Plan & Package Listing ---

  describe "get_plans/0" do
    test "returns subscription plans" do
      plans = Billing.get_plans()
      assert length(plans) == 2
      assert Enum.any?(plans, &(&1.id == "basic"))
      assert Enum.any?(plans, &(&1.id == "vip"))

      basic = Enum.find(plans, &(&1.id == "basic"))
      assert basic.price_jpy == 3980
      assert is_binary(basic.name_ja)
      assert is_binary(basic.name_en)
    end
  end

  describe "get_credit_packages/0" do
    test "returns credit packages" do
      packages = Billing.get_credit_packages()
      assert length(packages) == 3
      assert Enum.any?(packages, &(&1.id == "small"))
      assert Enum.any?(packages, &(&1.id == "medium"))
      assert Enum.any?(packages, &(&1.id == "large"))

      small = Enum.find(packages, &(&1.id == "small"))
      assert small.credits == 100
      assert small.price_jpy == 980
    end
  end

  # --- Credit Operations ---

  describe "add_credits/5" do
    test "adds credits and creates transaction" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      assert {:ok, result} = Billing.add_credits(user_id, 100, "purchase", "Test purchase")
      assert result.balance == 100

      # Verify user balance updated
      assert {:ok, 100} = Billing.get_credit_balance(user_id)
    end

    test "accumulates credits across multiple additions" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      assert {:ok, _} = Billing.add_credits(user_id, 100, "purchase", "First")
      assert {:ok, result} = Billing.add_credits(user_id, 50, "bonus", "Bonus")
      assert result.balance == 150
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} =
               Billing.add_credits("000000000000000000000000", 100, "purchase", "Test")
    end
  end

  describe "spend_credits/4" do
    test "spends credits and creates transaction" do
      user = create_test_user(%{credits: 200})
      user_id = to_string(user["_id"])

      assert {:ok, result} = Billing.spend_credits(user_id, 50, "Super like")
      assert result.balance == 150
    end

    test "returns error when insufficient credits" do
      user = create_test_user(%{credits: 30})
      user_id = to_string(user["_id"])

      assert {:error, :insufficient_credits} = Billing.spend_credits(user_id, 50, "Super like")

      # Balance should remain unchanged
      assert {:ok, 30} = Billing.get_credit_balance(user_id)
    end

    test "allows spending exact balance" do
      user = create_test_user(%{credits: 100})
      user_id = to_string(user["_id"])

      assert {:ok, result} = Billing.spend_credits(user_id, 100, "Boost")
      assert result.balance == 0
    end
  end

  describe "get_credit_balance/1" do
    test "returns balance for existing user" do
      user = create_test_user(%{credits: 250})
      assert {:ok, 250} = Billing.get_credit_balance(to_string(user["_id"]))
    end

    test "returns 0 for user with no credits field" do
      user = create_test_user()
      assert {:ok, 0} = Billing.get_credit_balance(to_string(user["_id"]))
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = Billing.get_credit_balance("000000000000000000000000")
    end
  end

  # --- Transaction History ---

  describe "list_transactions/2" do
    test "lists transactions for user" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      {:ok, _} = Billing.add_credits(user_id, 100, "purchase", "Buy credits")
      {:ok, _} = Billing.add_credits(user_id, 50, "bonus", "Monthly bonus")

      assert {:ok, result} = Billing.list_transactions(user_id)
      assert result.total == 2
      assert length(result.transactions) == 2
    end

    test "filters by type" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      {:ok, _} = Billing.add_credits(user_id, 100, "purchase", "Buy credits")
      {:ok, _} = Billing.add_credits(user_id, 50, "bonus", "Monthly bonus")

      assert {:ok, result} = Billing.list_transactions(user_id, type: "purchase")
      assert result.total == 1
      assert hd(result.transactions)["type"] == "purchase"
    end

    test "paginates results" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      for i <- 1..5 do
        {:ok, _} = Billing.add_credits(user_id, 10, "bonus", "Bonus #{i}")
      end

      assert {:ok, result} = Billing.list_transactions(user_id, page: 1, limit: 2)
      assert length(result.transactions) == 2
      assert result.total == 5
      assert result.total_pages == 3
    end

    test "returns empty list for user with no transactions" do
      user = create_test_user()
      assert {:ok, result} = Billing.list_transactions(to_string(user["_id"]))
      assert result.transactions == []
      assert result.total == 0
    end
  end

  # --- Subscription ---

  describe "get_subscription/1" do
    test "returns free plan for new user" do
      user = create_test_user()
      assert {:ok, sub} = Billing.get_subscription(to_string(user["_id"]))
      assert sub["plan"] == "free"
    end

    test "returns current subscription" do
      user =
        create_test_user(%{
          subscription: %{
            plan: "vip",
            expires_at: DateTime.add(DateTime.utc_now(), 86400, :second)
          }
        })

      assert {:ok, sub} = Billing.get_subscription(to_string(user["_id"]))
      assert sub["plan"] == "vip"
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = Billing.get_subscription("000000000000000000000000")
    end
  end

  describe "has_active_subscription?/1" do
    test "returns false for free plan" do
      user = create_test_user()
      refute Billing.has_active_subscription?(to_string(user["_id"]))
    end

    test "returns true for active subscription" do
      user =
        create_test_user(%{
          subscription: %{
            plan: "basic",
            expires_at: DateTime.add(DateTime.utc_now(), 86400, :second)
          }
        })

      assert Billing.has_active_subscription?(to_string(user["_id"]))
    end

    test "returns true for subscription without expiry" do
      user = create_test_user(%{subscription: %{plan: "vip", expires_at: nil}})
      assert Billing.has_active_subscription?(to_string(user["_id"]))
    end

    test "returns false for expired subscription" do
      user =
        create_test_user(%{
          subscription: %{
            plan: "basic",
            expires_at: DateTime.add(DateTime.utc_now(), -86400, :second)
          }
        })

      refute Billing.has_active_subscription?(to_string(user["_id"]))
    end

    test "returns false for non-existent user" do
      refute Billing.has_active_subscription?("000000000000000000000000")
    end
  end

  describe "cancel_subscription/1" do
    test "returns error when no active subscription" do
      user = create_test_user()

      assert {:error, "no_active_subscription"} =
               Billing.cancel_subscription(to_string(user["_id"]))
    end

    test "cancels subscription without stripe ID" do
      user = create_test_user(%{subscription: %{plan: "basic", expires_at: nil}})
      user_id = to_string(user["_id"])

      assert {:ok, result} = Billing.cancel_subscription(user_id)
      assert result.status == "canceled"

      assert {:ok, sub} = Billing.get_subscription(user_id)
      assert sub["plan"] == "free"
    end
  end

  # --- Checkout Sessions (mock mode) ---

  describe "create_checkout_session/2" do
    test "creates mock checkout session for subscription" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      assert {:ok, result} = Billing.create_checkout_session(user_id, "basic")
      assert is_binary(result.checkout_url)
      assert is_binary(result.session_id)
    end

    test "rejects invalid plan" do
      user = create_test_user()

      assert {:error, "invalid_plan"} =
               Billing.create_checkout_session(to_string(user["_id"]), "invalid")
    end
  end

  describe "create_credit_purchase_session/2" do
    test "creates mock checkout session for credits" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      assert {:ok, result} = Billing.create_credit_purchase_session(user_id, "medium")
      assert is_binary(result.checkout_url)
      assert is_binary(result.session_id)
    end

    test "rejects invalid package" do
      user = create_test_user()

      assert {:error, "invalid_package"} =
               Billing.create_credit_purchase_session(to_string(user["_id"]), "invalid")
    end
  end

  # --- Webhook Handlers ---

  describe "handle_checkout_completed/1 for subscriptions" do
    test "updates user subscription on checkout completed" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      session = %{
        "mode" => "subscription",
        "metadata" => %{"user_id" => user_id, "plan" => "vip"},
        "subscription" => "sub_mock_123"
      }

      assert :ok = Billing.handle_checkout_completed(session)

      assert {:ok, sub} = Billing.get_subscription(user_id)
      assert sub["plan"] == "vip"
      assert sub["stripe_subscription_id"] == "sub_mock_123"
    end
  end

  describe "handle_checkout_completed/1 for credit purchases" do
    test "adds credits on payment checkout completed" do
      user = create_test_user()
      user_id = to_string(user["_id"])

      session = %{
        "mode" => "payment",
        "id" => "cs_mock_123",
        "metadata" => %{"user_id" => user_id, "package" => "medium"}
      }

      assert {:ok, _} = Billing.handle_checkout_completed(session)
      assert {:ok, 300} = Billing.get_credit_balance(user_id)
    end
  end

  describe "handle_subscription_deleted/1" do
    test "reverts to free plan" do
      user =
        create_test_user(%{
          subscription: %{plan: "vip", expires_at: nil, stripe_subscription_id: "sub_123"},
          stripe_customer_id: "cus_test_123"
        })

      user_id = to_string(user["_id"])

      subscription = %{
        "id" => "sub_123",
        "customer" => "cus_test_123"
      }

      assert :ok = Billing.handle_subscription_deleted(subscription)

      assert {:ok, sub} = Billing.get_subscription(user_id)
      assert sub["plan"] == "free"
    end
  end
end
