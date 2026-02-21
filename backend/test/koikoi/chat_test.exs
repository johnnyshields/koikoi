defmodule Koikoi.ChatTest do
  use ExUnit.Case, async: false

  import Koikoi.AccountHelpers

  alias Koikoi.{Chat, Repo, Accounts}

  @moduletag :mongodb

  setup do
    Repo.delete_many("conversations", %{})
    Repo.delete_many("messages", %{})
    Repo.delete_many("notifications", %{})
    Repo.delete_many("users", %{})
    :ok
  end

  defp id(user), do: to_string(user["_id"])

  defp create_female_user(phone) do
    create_test_user(%{"phone_number" => phone, "gender" => "female"})
  end

  defp create_male_user(phone, subscription \\ %{"plan" => "free", "expires_at" => nil}) do
    user = create_test_user(%{"phone_number" => phone, "gender" => "male"})

    Repo.update_one(
      "users",
      %{_id: user["_id"]},
      %{"$set" => %{subscription: subscription}}
    )

    Accounts.get_user(id(user))
  end

  defp create_paid_male_user(phone) do
    expires = DateTime.add(DateTime.utc_now(), 30 * 24 * 3600, :second)

    create_male_user(phone, %{
      "plan" => "premium",
      "expires_at" => expires
    })
  end

  # --- Conversation Tests ---

  describe "create_conversation/3" do
    test "creates a conversation between two users" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      assert conversation["status"] == "active"
      assert length(conversation["participants"]) == 2
      assert conversation["last_message_at"] == nil
    end
  end

  describe "get_conversation/2" do
    test "returns conversation for participant" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      assert {:ok, found} = Chat.get_conversation(conv_id, id(user_a))
      assert to_string(found["_id"]) == conv_id
    end

    test "returns unauthorized for non-participant" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")
      stranger = create_female_user("+81900000003")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      assert {:error, :unauthorized} = Chat.get_conversation(conv_id, id(stranger))
    end

    test "returns not_found for invalid id" do
      user_a = create_female_user("+81900000001")
      assert {:error, :not_found} = Chat.get_conversation("507f1f77bcf86cd799439011", id(user_a))
    end
  end

  # --- Message Tests ---

  describe "send_message/3" do
    test "women can always send messages" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      assert {:ok, message} =
               Chat.send_message(conv_id, id(user_a), %{
                 "content" => "Hello!",
                 "message_type" => "text"
               })

      assert message["content"] == "Hello!"
      assert message["message_type"] == "text"
      assert message["read_at"] == nil
    end

    test "men with paid subscription can send messages" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      assert {:ok, message} =
               Chat.send_message(conv_id, id(user_b), %{
                 "content" => "Hey!",
                 "message_type" => "text"
               })

      assert message["content"] == "Hey!"
    end

    test "men on free plan cannot send messages" do
      user_a = create_female_user("+81900000001")
      user_b = create_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      assert {:error, :subscription_required} =
               Chat.send_message(conv_id, id(user_b), %{
                 "content" => "Hello!",
                 "message_type" => "text"
               })
    end

    test "updates last_message_at on conversation" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      {:ok, _msg} =
        Chat.send_message(conv_id, id(user_a), %{
          "content" => "Hello!",
          "message_type" => "text"
        })

      {:ok, updated_conv} = Chat.get_conversation(conv_id, id(user_a))
      assert updated_conv["last_message_at"] != nil
    end
  end

  describe "list_messages/3" do
    test "returns messages for a conversation" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      {:ok, _} = Chat.send_message(conv_id, id(user_a), %{"content" => "First"})
      {:ok, _} = Chat.send_message(conv_id, id(user_b), %{"content" => "Second"})

      {:ok, messages} = Chat.list_messages(conv_id, id(user_a))

      assert length(messages) == 2
    end
  end

  # --- Read Receipts ---

  describe "mark_read/2" do
    test "marks messages from the other person as read" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      {:ok, msg} = Chat.send_message(conv_id, id(user_a), %{"content" => "Hello!"})
      assert msg["read_at"] == nil

      # user_b marks as read
      :ok = Chat.mark_read(conv_id, id(user_b))

      # Verify message now has read_at
      {:ok, messages} = Chat.list_messages(conv_id, id(user_b))
      message = hd(messages)
      assert message["read_at"] != nil
    end

    test "does not mark own messages as read" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      {:ok, _msg} = Chat.send_message(conv_id, id(user_a), %{"content" => "Hello!"})

      # user_a (sender) marks as read - should NOT mark own messages
      :ok = Chat.mark_read(conv_id, id(user_a))

      {:ok, messages} = Chat.list_messages(conv_id, id(user_a))
      message = hd(messages)
      assert message["read_at"] == nil
    end
  end

  # --- Unread Count ---

  describe "get_unread_count/1" do
    test "returns correct unread count" do
      user_a = create_female_user("+81900000001")
      user_b = create_paid_male_user("+81900000002")

      {:ok, conversation} =
        Chat.create_conversation("507f1f77bcf86cd799439011", id(user_a), id(user_b))

      conv_id = to_string(conversation["_id"])

      {:ok, _} = Chat.send_message(conv_id, id(user_a), %{"content" => "One"})
      {:ok, _} = Chat.send_message(conv_id, id(user_a), %{"content" => "Two"})

      {:ok, count} = Chat.get_unread_count(id(user_b))
      assert count == 2

      # User A should have 0 unread (they sent both)
      {:ok, count_a} = Chat.get_unread_count(id(user_a))
      assert count_a == 0
    end

    test "returns 0 when no conversations" do
      user_a = create_female_user("+81900000001")
      {:ok, count} = Chat.get_unread_count(id(user_a))
      assert count == 0
    end
  end

  # --- Subscription Check ---

  describe "can_send_message?/1" do
    test "women can always send" do
      user = create_female_user("+81900000001")
      assert Chat.can_send_message?(id(user)) == true
    end

    test "men on free plan cannot send" do
      user = create_male_user("+81900000001")
      assert Chat.can_send_message?(id(user)) == false
    end

    test "men with active subscription can send" do
      user = create_paid_male_user("+81900000001")
      assert Chat.can_send_message?(id(user)) == true
    end

    test "men with expired subscription cannot send" do
      expired = DateTime.add(DateTime.utc_now(), -1 * 24 * 3600, :second)

      user =
        create_male_user("+81900000001", %{
          "plan" => "premium",
          "expires_at" => expired
        })

      assert Chat.can_send_message?(id(user)) == false
    end
  end
end
