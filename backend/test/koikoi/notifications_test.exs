defmodule Koikoi.NotificationsTest do
  use ExUnit.Case, async: false

  import Koikoi.AccountHelpers

  alias Koikoi.{Notifications, Repo}

  @moduletag :mongodb

  setup do
    Repo.delete_many("notifications", %{})
    Repo.delete_many("users", %{})
    :ok
  end

  defp id(user), do: to_string(user["_id"])

  # --- Creation ---

  describe "create_notification/5" do
    test "creates a notification" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, notification} =
        Notifications.create_notification(
          id(user),
          "new_match",
          "新しいマッチ",
          "You have a new match!",
          %{"match_id" => "abc123"}
        )

      assert notification["type"] == "new_match"
      assert notification["title"] == "新しいマッチ"
      assert notification["body"] == "You have a new match!"
      assert notification["data"]["match_id"] == "abc123"
      assert notification["read"] == false
    end
  end

  # --- Listing ---

  describe "list_notifications/2" do
    test "returns notifications in reverse chronological order" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, _} = Notifications.create_notification(id(user), "new_match", "First", "First body")

      {:ok, _} =
        Notifications.create_notification(id(user), "new_message", "Second", "Second body")

      {:ok, notifications} = Notifications.list_notifications(id(user))

      assert length(notifications) == 2
      # Most recent first
      assert hd(notifications)["type"] == "new_message"
    end

    test "filters by unread_only" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, notif1} =
        Notifications.create_notification(id(user), "new_match", "First", "First body")

      {:ok, _} =
        Notifications.create_notification(id(user), "new_message", "Second", "Second body")

      # Mark first as read
      Notifications.mark_read(to_string(notif1["_id"]), id(user))

      {:ok, unread} = Notifications.list_notifications(id(user), unread_only: true)
      assert length(unread) == 1
      assert hd(unread)["type"] == "new_message"
    end

    test "paginates results" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      for i <- 1..5 do
        Notifications.create_notification(id(user), "new_match", "Notif #{i}", "Body #{i}")
      end

      {:ok, page1} = Notifications.list_notifications(id(user), page: 1, limit: 2)
      assert length(page1) == 2

      {:ok, page2} = Notifications.list_notifications(id(user), page: 2, limit: 2)
      assert length(page2) == 2

      {:ok, page3} = Notifications.list_notifications(id(user), page: 3, limit: 2)
      assert length(page3) == 1
    end
  end

  # --- Mark Read ---

  describe "mark_read/2" do
    test "marks a notification as read" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, notification} =
        Notifications.create_notification(id(user), "new_match", "Title", "Body")

      notif_id = to_string(notification["_id"])

      {:ok, updated} = Notifications.mark_read(notif_id, id(user))
      assert updated["read"] == true
    end

    test "returns not_found for wrong user" do
      user_a = create_test_user(%{"phone_number" => "+81900000001"})
      user_b = create_test_user(%{"phone_number" => "+81900000002"})

      {:ok, notification} =
        Notifications.create_notification(id(user_a), "new_match", "Title", "Body")

      notif_id = to_string(notification["_id"])

      assert {:error, :not_found} = Notifications.mark_read(notif_id, id(user_b))
    end
  end

  describe "mark_all_read/1" do
    test "marks all notifications as read" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, _} = Notifications.create_notification(id(user), "new_match", "First", "Body")
      {:ok, _} = Notifications.create_notification(id(user), "new_message", "Second", "Body")

      :ok = Notifications.mark_all_read(id(user))

      {:ok, unread} = Notifications.list_notifications(id(user), unread_only: true)
      assert length(unread) == 0
    end
  end

  # --- Unread Count ---

  describe "get_unread_count/1" do
    test "returns correct unread count" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, _} = Notifications.create_notification(id(user), "new_match", "First", "Body")
      {:ok, _} = Notifications.create_notification(id(user), "new_message", "Second", "Body")

      count = Notifications.get_unread_count(id(user))
      assert count == 2
    end

    test "returns 0 when all read" do
      user = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, _} = Notifications.create_notification(id(user), "new_match", "First", "Body")
      Notifications.mark_all_read(id(user))

      count = Notifications.get_unread_count(id(user))
      assert count == 0
    end

    test "returns 0 for user with no notifications" do
      user = create_test_user(%{"phone_number" => "+81900000001"})
      count = Notifications.get_unread_count(id(user))
      assert count == 0
    end
  end
end
