defmodule Koikoi.SocialTest do
  use ExUnit.Case, async: false

  import Koikoi.AccountHelpers

  alias Koikoi.Social
  alias Koikoi.Repo

  @moduletag :mongodb

  setup do
    Repo.delete_many("connections", %{})
    Repo.delete_many("users", %{})
    Repo.delete_many("phone_verifications", %{})
    :ok
  end

  defp create_two_users do
    user_a = create_test_user(%{"phone_number" => "+81901111111"})
    user_b = create_test_user(%{"phone_number" => "+81902222222"})
    {user_a, user_b}
  end

  defp create_three_users do
    user_a = create_test_user(%{"phone_number" => "+81901111111"})
    user_b = create_test_user(%{"phone_number" => "+81902222222"})
    user_c = create_test_user(%{"phone_number" => "+81903333333"})
    {user_a, user_b, user_c}
  end

  defp id(user), do: to_string(user["_id"])

  # --- Friend Request Flow ---

  describe "send_friend_request/2" do
    test "creates a pending friend connection" do
      {user_a, user_b} = create_two_users()

      assert {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))
      assert connection["type"] == "friend"
      assert connection["status"] == "pending"
      assert connection["trust_tier"] == "friends"
      assert connection["requester_id"] == user_a["_id"]
      assert connection["recipient_id"] == user_b["_id"]
    end

    test "rejects duplicate friend request" do
      {user_a, user_b} = create_two_users()

      assert {:ok, _} = Social.send_friend_request(id(user_a), id(user_b))

      assert {:error, "connection_already_exists"} =
               Social.send_friend_request(id(user_a), id(user_b))
    end

    test "rejects reverse duplicate friend request" do
      {user_a, user_b} = create_two_users()

      assert {:ok, _} = Social.send_friend_request(id(user_a), id(user_b))

      assert {:error, "connection_already_exists"} =
               Social.send_friend_request(id(user_b), id(user_a))
    end

    test "rejects self-friend request" do
      {user_a, _user_b} = create_two_users()

      assert {:error, "cannot_connect_to_self"} =
               Social.send_friend_request(id(user_a), id(user_a))
    end
  end

  describe "accept_friend_request/2" do
    test "accepts a pending friend request as recipient" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      assert {:ok, updated} = Social.accept_friend_request(conn_id, id(user_b))
      assert updated["status"] == "accepted"
    end

    test "rejects accept from non-recipient" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      assert {:error, :unauthorized} = Social.accept_friend_request(conn_id, id(user_a))
    end

    test "returns not_found for invalid connection_id" do
      {_user_a, user_b} = create_two_users()
      fake_id = "507f1f77bcf86cd799439011"

      assert {:error, :not_found} = Social.accept_friend_request(fake_id, id(user_b))
    end
  end

  describe "decline_friend_request/2" do
    test "declines a pending friend request" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      assert {:ok, updated} = Social.decline_friend_request(conn_id, id(user_b))
      assert updated["status"] == "declined"
    end

    test "rejects decline from non-recipient" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      assert {:error, :unauthorized} = Social.decline_friend_request(conn_id, id(user_a))
    end
  end

  describe "remove_friend/2" do
    test "removes an accepted friend connection" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      {:ok, _} = Social.accept_friend_request(conn_id, id(user_b))

      assert :ok = Social.remove_friend(id(user_a), id(user_b))

      # Verify it's gone
      assert {:ok, []} = Social.list_friends(id(user_a))
    end

    test "returns not_found when no friendship exists" do
      {user_a, user_b} = create_two_users()
      assert {:error, :not_found} = Social.remove_friend(id(user_a), id(user_b))
    end
  end

  describe "list_friends/2" do
    test "lists accepted friends" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, conn1} = Social.send_friend_request(id(user_a), id(user_b))
      {:ok, _conn2} = Social.send_friend_request(id(user_c), id(user_a))

      Social.accept_friend_request(to_string(conn1["_id"]), id(user_b))

      assert {:ok, friends} = Social.list_friends(id(user_a))
      assert length(friends) == 1
    end

    test "returns empty list when no friends" do
      {user_a, _user_b} = create_two_users()
      assert {:ok, []} = Social.list_friends(id(user_a))
    end
  end

  describe "list_pending_requests/1" do
    test "lists pending requests where user is recipient" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, _} = Social.send_friend_request(id(user_a), id(user_b))
      {:ok, _} = Social.send_friend_request(id(user_c), id(user_b))

      assert {:ok, requests} = Social.list_pending_requests(id(user_b))
      assert length(requests) == 2
    end

    test "does not include requests where user is requester" do
      {user_a, user_b} = create_two_users()

      {:ok, _} = Social.send_friend_request(id(user_a), id(user_b))

      assert {:ok, requests} = Social.list_pending_requests(id(user_a))
      assert length(requests) == 0
    end
  end

  # --- Matchmaker Flow ---

  describe "invite_matchmaker/2" do
    test "creates a pending matchmaker connection" do
      {user_a, user_b} = create_two_users()

      assert {:ok, connection} = Social.invite_matchmaker(id(user_a), id(user_b))
      assert connection["type"] == "matchmaker"
      assert connection["status"] == "pending"
      assert connection["matchmaker_id"] == user_b["_id"]
      assert connection["subject_id"] == user_a["_id"]
    end

    test "rejects duplicate matchmaker invite" do
      {user_a, user_b} = create_two_users()

      assert {:ok, _} = Social.invite_matchmaker(id(user_a), id(user_b))

      assert {:error, "matchmaker_connection_already_exists"} =
               Social.invite_matchmaker(id(user_a), id(user_b))
    end

    test "rejects self-matchmaker invite" do
      {user_a, _user_b} = create_two_users()

      assert {:error, "cannot_connect_to_self"} = Social.invite_matchmaker(id(user_a), id(user_a))
    end
  end

  describe "accept_matchmaker_invite/2" do
    test "accepts a pending matchmaker invite as recipient" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.invite_matchmaker(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      assert {:ok, updated} = Social.accept_matchmaker_invite(conn_id, id(user_b))
      assert updated["status"] == "accepted"
    end

    test "rejects accept from non-recipient" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.invite_matchmaker(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      assert {:error, :unauthorized} = Social.accept_matchmaker_invite(conn_id, id(user_a))
    end
  end

  describe "decline_matchmaker_invite/2" do
    test "declines a pending matchmaker invite" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.invite_matchmaker(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      assert {:ok, updated} = Social.decline_matchmaker_invite(conn_id, id(user_b))
      assert updated["status"] == "declined"
    end
  end

  describe "remove_matchmaker/2" do
    test "removes an accepted matchmaker connection" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.invite_matchmaker(id(user_a), id(user_b))

      conn_id = to_string(connection["_id"])
      {:ok, _} = Social.accept_matchmaker_invite(conn_id, id(user_b))

      assert :ok = Social.remove_matchmaker(id(user_a), id(user_b))
      assert {:ok, []} = Social.list_matchmakers(id(user_a))
    end
  end

  describe "list_matchmakers/1" do
    test "lists accepted matchmakers for a user" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, conn1} = Social.invite_matchmaker(id(user_a), id(user_b))
      {:ok, conn2} = Social.invite_matchmaker(id(user_a), id(user_c))

      Social.accept_matchmaker_invite(to_string(conn1["_id"]), id(user_b))
      Social.accept_matchmaker_invite(to_string(conn2["_id"]), id(user_c))

      assert {:ok, matchmakers} = Social.list_matchmakers(id(user_a))
      assert length(matchmakers) == 2
    end
  end

  describe "list_matchmaker_subjects/1" do
    test "lists users that this matchmaker is responsible for" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, conn1} = Social.invite_matchmaker(id(user_a), id(user_c))
      {:ok, conn2} = Social.invite_matchmaker(id(user_b), id(user_c))

      Social.accept_matchmaker_invite(to_string(conn1["_id"]), id(user_c))
      Social.accept_matchmaker_invite(to_string(conn2["_id"]), id(user_c))

      assert {:ok, subjects} = Social.list_matchmaker_subjects(id(user_c))
      assert length(subjects) == 2
    end
  end

  # --- Trust Tier ---

  describe "get_trust_tier/2" do
    test "returns trust_tier for direct friends" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))

      Social.accept_friend_request(to_string(connection["_id"]), id(user_b))

      assert "friends" = Social.get_trust_tier(id(user_a), id(user_b))
    end

    test "returns 'verified' for matchmaker relationship" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.invite_matchmaker(id(user_a), id(user_b))

      Social.accept_matchmaker_invite(to_string(connection["_id"]), id(user_b))

      assert "verified" = Social.get_trust_tier(id(user_a), id(user_b))
    end

    test "returns 'open' for strangers" do
      {user_a, user_b} = create_two_users()

      assert "open" = Social.get_trust_tier(id(user_a), id(user_b))
    end

    test "returns friend tier over matchmaker tier when both exist" do
      {user_a, user_b} = create_two_users()

      {:ok, friend_conn} = Social.send_friend_request(id(user_a), id(user_b))
      Social.accept_friend_request(to_string(friend_conn["_id"]), id(user_b))

      {:ok, mm_conn} = Social.invite_matchmaker(id(user_a), id(user_b))
      Social.accept_matchmaker_invite(to_string(mm_conn["_id"]), id(user_b))

      # Should return the friend trust tier, not "verified"
      assert "friends" = Social.get_trust_tier(id(user_a), id(user_b))
    end
  end

  describe "update_trust_tier/3" do
    test "updates trust tier for a friend connection" do
      {user_a, user_b} = create_two_users()
      {:ok, connection} = Social.send_friend_request(id(user_a), id(user_b))

      Social.accept_friend_request(to_string(connection["_id"]), id(user_b))

      assert {:ok, updated} = Social.update_trust_tier(id(user_a), id(user_b), "inner_circle")
      assert updated["trust_tier"] == "inner_circle"

      # Verify get_trust_tier reflects the change
      assert "inner_circle" = Social.get_trust_tier(id(user_a), id(user_b))
    end

    test "rejects invalid trust tier" do
      {user_a, user_b} = create_two_users()

      assert {:error, "invalid_trust_tier"} =
               Social.update_trust_tier(id(user_a), id(user_b), "invalid")
    end

    test "returns not_found when no friendship exists" do
      {user_a, user_b} = create_two_users()

      assert {:error, :not_found} =
               Social.update_trust_tier(id(user_a), id(user_b), "inner_circle")
    end
  end

  # --- Invite Codes ---

  describe "redeem_invite_code/2" do
    test "creates friend request when redeeming valid invite code" do
      {user_a, user_b} = create_two_users()
      inviter_code = user_b["invite_code"]

      assert {:ok, connection} = Social.redeem_invite_code(id(user_a), inviter_code)
      assert connection["type"] == "friend"
      assert connection["status"] == "pending"
      assert connection["requester_id"] == user_a["_id"]
      assert connection["recipient_id"] == user_b["_id"]
    end

    test "increments inviter's matchmaker_invites_sent" do
      {user_a, user_b} = create_two_users()
      inviter_code = user_b["invite_code"]

      {:ok, _} = Social.redeem_invite_code(id(user_a), inviter_code)

      updated_inviter = Repo.find_one("users", %{_id: user_b["_id"]})
      assert updated_inviter["matchmaker_invites_sent"] == 1
    end

    test "rejects invalid invite code" do
      {user_a, _user_b} = create_two_users()
      assert {:error, "invalid_invite_code"} = Social.redeem_invite_code(id(user_a), "BADCODE1")
    end

    test "rejects own invite code" do
      {user_a, _user_b} = create_two_users()
      own_code = user_a["invite_code"]

      assert {:error, "cannot_redeem_own_code"} = Social.redeem_invite_code(id(user_a), own_code)
    end

    test "rejects already connected users" do
      {user_a, user_b} = create_two_users()
      inviter_code = user_b["invite_code"]

      {:ok, _} = Social.redeem_invite_code(id(user_a), inviter_code)
      assert {:error, "already_connected"} = Social.redeem_invite_code(id(user_a), inviter_code)
    end
  end

  describe "get_invite_stats/1" do
    test "returns invite code and stats" do
      {user_a, _user_b} = create_two_users()

      assert {:ok, stats} = Social.get_invite_stats(id(user_a))
      assert is_binary(stats.invite_code)
      assert stats.invites_sent == 0
    end
  end

  # --- Matchmaking Activation ---

  describe "is_matchmaking_active?/1" do
    test "returns false with fewer than 2 matchmakers" do
      {user_a, user_b} = create_two_users()

      {:ok, conn} = Social.invite_matchmaker(id(user_a), id(user_b))
      Social.accept_matchmaker_invite(to_string(conn["_id"]), id(user_b))

      refute Social.is_matchmaking_active?(id(user_a))
    end

    test "returns true with 2+ accepted matchmakers" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, conn1} = Social.invite_matchmaker(id(user_a), id(user_b))
      {:ok, conn2} = Social.invite_matchmaker(id(user_a), id(user_c))

      Social.accept_matchmaker_invite(to_string(conn1["_id"]), id(user_b))
      Social.accept_matchmaker_invite(to_string(conn2["_id"]), id(user_c))

      assert Social.is_matchmaking_active?(id(user_a))
    end

    test "does not count pending matchmakers" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, conn1} = Social.invite_matchmaker(id(user_a), id(user_b))
      {:ok, _conn2} = Social.invite_matchmaker(id(user_a), id(user_c))

      # Only accept one
      Social.accept_matchmaker_invite(to_string(conn1["_id"]), id(user_b))

      refute Social.is_matchmaking_active?(id(user_a))
    end
  end

  describe "get_matchmaker_count/1" do
    test "returns count of accepted matchmakers" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, conn1} = Social.invite_matchmaker(id(user_a), id(user_b))
      {:ok, conn2} = Social.invite_matchmaker(id(user_a), id(user_c))

      Social.accept_matchmaker_invite(to_string(conn1["_id"]), id(user_b))
      Social.accept_matchmaker_invite(to_string(conn2["_id"]), id(user_c))

      assert 2 == Social.get_matchmaker_count(id(user_a))
    end
  end

  # --- Matchmaker Permissions ---

  describe "can_matchmake?/2" do
    test "returns true when matchmaker has permission" do
      {user_a, user_b} = create_two_users()

      {:ok, conn} = Social.invite_matchmaker(id(user_a), id(user_b))
      Social.accept_matchmaker_invite(to_string(conn["_id"]), id(user_b))

      assert Social.can_matchmake?(id(user_b), id(user_a))
    end

    test "returns false without permission" do
      {user_a, user_b} = create_two_users()

      refute Social.can_matchmake?(id(user_b), id(user_a))
    end
  end

  describe "get_matchable_users/1" do
    test "returns list of user IDs matchmaker can match" do
      {user_a, user_b, user_c} = create_three_users()

      {:ok, conn1} = Social.invite_matchmaker(id(user_a), id(user_c))
      {:ok, conn2} = Social.invite_matchmaker(id(user_b), id(user_c))

      Social.accept_matchmaker_invite(to_string(conn1["_id"]), id(user_c))
      Social.accept_matchmaker_invite(to_string(conn2["_id"]), id(user_c))

      assert {:ok, user_ids} = Social.get_matchable_users(id(user_c))
      assert length(user_ids) == 2
      assert id(user_a) in user_ids
      assert id(user_b) in user_ids
    end
  end
end
