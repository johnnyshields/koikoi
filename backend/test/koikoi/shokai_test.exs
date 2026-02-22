defmodule Koikoi.ShokaiTest do
  use ExUnit.Case, async: false

  import Koikoi.AccountHelpers

  alias Koikoi.{Shokai, Repo}

  @moduletag :mongodb

  setup do
    Repo.delete_many("shokais", %{})
    Repo.delete_many("conversations", %{})
    Repo.delete_many("messages", %{})
    Repo.delete_many("notifications", %{})
    Repo.delete_many("connections", %{})
    Repo.delete_many("users", %{})
    :ok
  end

  defp id(user), do: to_string(user["_id"])

  defp create_user(phone) do
    create_test_user(%{"phone_number" => phone, "gender" => "female"})
  end

  defp create_friendship(user_a, user_b) do
    now = DateTime.utc_now()

    Repo.insert_one("connections", %{
      requester_id: user_a["_id"],
      recipient_id: user_b["_id"],
      type: "friend",
      trust_tier: "friends",
      status: "accepted",
      matchmaker_id: nil,
      subject_id: nil,
      inserted_at: now,
      updated_at: now
    })
  end

  describe "create_shokai/4" do
    test "creates a shokai when matchmaker is friends with both" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      assert {:ok, shokai} =
               Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))

      assert shokai["status"] == "pending"
      assert shokai["person_a_response"] == "pending"
      assert shokai["person_b_response"] == "pending"
    end

    test "fails if matchmaker is not friends with both" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      # No friendship with person_b

      assert {:error, :not_friends_with_both} =
               Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))
    end

    test "prevents duplicate active shokais for same pair" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      {:ok, _} = Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))

      assert {:error, :active_shokai_exists} =
               Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))
    end
  end

  describe "respond_to_shokai/3" do
    test "records a person's acceptance" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      {:ok, shokai} = Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))
      shokai_id = to_string(shokai["_id"])

      # Figure out which person is person_a vs person_b in the canonical ordering
      pa_str = to_string(shokai["person_a_id"])

      assert {:ok, updated} = Shokai.respond_to_shokai(shokai_id, pa_str, "accepted")
      assert updated["person_a_response"] == "accepted"
      assert updated["status"] == "pending"
    end

    test "creates conversation when both accept" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      {:ok, shokai} = Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))
      shokai_id = to_string(shokai["_id"])

      pa_str = to_string(shokai["person_a_id"])
      pb_str = to_string(shokai["person_b_id"])

      {:ok, _} = Shokai.respond_to_shokai(shokai_id, pa_str, "accepted")
      {:ok, final} = Shokai.respond_to_shokai(shokai_id, pb_str, "accepted")

      assert final["status"] == "accepted"
      assert final["result_conversation_id"] != nil
    end

    test "marks as declined when either person declines" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      {:ok, shokai} = Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))
      shokai_id = to_string(shokai["_id"])

      pa_str = to_string(shokai["person_a_id"])

      {:ok, updated} = Shokai.respond_to_shokai(shokai_id, pa_str, "declined")
      assert updated["status"] == "declined"
    end

    test "returns error for unauthorized user" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      stranger = create_user("+81900000053")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      {:ok, shokai} = Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))
      shokai_id = to_string(shokai["_id"])

      assert {:error, :unauthorized} =
               Shokai.respond_to_shokai(shokai_id, id(stranger), "accepted")
    end
  end

  describe "list_pending/1" do
    test "returns pending shokais for user" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      {:ok, _} = Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))

      {:ok, pending} = Shokai.list_pending(id(person_a))
      assert length(pending) == 1
    end
  end

  describe "expire_stale/0" do
    test "expires shokais past their deadline" do
      matchmaker = create_user("+81900000050")
      person_a = create_user("+81900000051")
      person_b = create_user("+81900000052")
      create_friendship(matchmaker, person_a)
      create_friendship(matchmaker, person_b)

      {:ok, shokai} = Shokai.create_shokai(id(matchmaker), id(person_a), id(person_b))

      # Manually set expires_at to the past
      past = DateTime.add(DateTime.utc_now(), -3600, :second)

      Repo.update_one(
        "shokais",
        %{_id: shokai["_id"]},
        %{"$set" => %{expires_at: past}}
      )

      Shokai.expire_stale()

      updated = Repo.find_one("shokais", %{_id: shokai["_id"]})
      assert updated["status"] == "expired"
    end
  end
end
