defmodule Koikoi.Chat do
  @moduledoc "The Chat context manages conversations and messages."

  alias Koikoi.{Repo, Accounts}

  @conversations_collection "conversations"
  @messages_collection "messages"

  # --- Conversations ---

  def create_conversation(match_id, person_a_id, person_b_id) do
    now = DateTime.utc_now()

    document = %{
      match_id: to_oid(match_id),
      participants: [to_oid(person_a_id), to_oid(person_b_id)],
      status: "active",
      last_message_at: nil,
      inserted_at: now,
      updated_at: now
    }

    case Repo.insert_one(@conversations_collection, document) do
      {:ok, result} ->
        conversation = Repo.find_one(@conversations_collection, %{_id: result.inserted_id})
        {:ok, conversation}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_conversation(conversation_id, user_id) do
    conv_oid = to_oid(conversation_id)
    user_oid = to_oid(user_id)

    case Repo.find_one(@conversations_collection, %{_id: conv_oid}) do
      nil ->
        {:error, :not_found}

      conversation ->
        participants = conversation["participants"] || []
        participant_strings = Enum.map(participants, &to_string/1)

        if to_string(user_oid) in participant_strings do
          {:ok, conversation}
        else
          {:error, :unauthorized}
        end
    end
  end

  def list_conversations(user_id, opts \\ []) do
    user_oid = to_oid(user_id)
    page = Keyword.get(opts, :page, 1)
    limit = Keyword.get(opts, :limit, 20)
    skip = (page - 1) * limit

    conversations =
      Repo.find(
        @conversations_collection,
        %{participants: user_oid, status: "active"},
        sort: %{last_message_at: -1, inserted_at: -1},
        skip: skip,
        limit: limit
      )
      |> Enum.to_list()

    # Attach last message preview for each conversation
    conversations_with_preview =
      Enum.map(conversations, fn conv ->
        last_message =
          Repo.find_one(
            @messages_collection,
            %{conversation_id: conv["_id"]},
            sort: %{inserted_at: -1}
          )

        Map.put(conv, "last_message", last_message)
      end)

    {:ok, conversations_with_preview}
  end

  # --- Messages ---

  def send_message(conversation_id, sender_id, attrs) do
    conv_oid = to_oid(conversation_id)
    sender_oid = to_oid(sender_id)

    with {:ok, conversation} <- get_conversation(conversation_id, sender_id),
         :ok <- check_can_send(sender_id) do
      now = DateTime.utc_now()

      message = %{
        conversation_id: conv_oid,
        sender_id: sender_oid,
        content: attrs["content"],
        message_type: attrs["message_type"] || "text",
        read_at: nil,
        inserted_at: now
      }

      case Repo.insert_one(@messages_collection, message) do
        {:ok, result} ->
          # Update last_message_at on conversation
          Repo.update_one(
            @conversations_collection,
            %{_id: conversation["_id"]},
            %{"$set" => %{last_message_at: now, updated_at: now}}
          )

          msg = Repo.find_one(@messages_collection, %{_id: result.inserted_id})

          # Create notification for the other participant
          notify_new_message(conversation, sender_id, msg)

          {:ok, msg}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def list_messages(conversation_id, user_id, opts \\ []) do
    with {:ok, _conversation} <- get_conversation(conversation_id, user_id) do
      conv_oid = to_oid(conversation_id)
      limit = Keyword.get(opts, :limit, 50)

      filter =
        case Keyword.get(opts, :before) do
          nil ->
            %{conversation_id: conv_oid}

          before_id ->
            %{conversation_id: conv_oid, _id: %{"$lt" => to_oid(before_id)}}
        end

      messages =
        Repo.find(
          @messages_collection,
          filter,
          sort: %{inserted_at: -1},
          limit: limit
        )
        |> Enum.to_list()

      {:ok, messages}
    end
  end

  def mark_read(conversation_id, user_id) do
    conv_oid = to_oid(conversation_id)
    user_oid = to_oid(user_id)
    now = DateTime.utc_now()

    # Mark all messages NOT from this user as read
    Repo.update_many(
      @messages_collection,
      %{
        conversation_id: conv_oid,
        sender_id: %{"$ne" => user_oid},
        read_at: nil
      },
      %{"$set" => %{read_at: now}}
    )

    :ok
  end

  def get_unread_count(user_id) do
    user_oid = to_oid(user_id)

    # Get all conversation IDs for this user
    conversations =
      Repo.find(
        @conversations_collection,
        %{participants: user_oid, status: "active"}
      )
      |> Enum.to_list()

    conv_ids = Enum.map(conversations, & &1["_id"])

    if conv_ids == [] do
      {:ok, 0}
    else
      count =
        Repo.count_documents(@messages_collection, %{
          conversation_id: %{"$in" => conv_ids},
          sender_id: %{"$ne" => user_oid},
          read_at: nil
        })

      {:ok, count}
    end
  end

  # --- Subscription Check ---

  def can_send_message?(user_id) do
    user = Accounts.get_user(user_id)

    cond do
      user == nil ->
        false

      user["gender"] == "female" ->
        true

      true ->
        # Men need active subscription
        subscription = user["subscription"] || %{}
        plan = subscription["plan"] || "free"

        if plan == "free" do
          false
        else
          case subscription["expires_at"] do
            nil ->
              false

            expires_at ->
              DateTime.compare(expires_at, DateTime.utc_now()) == :gt
          end
        end
    end
  end

  # --- Private Helpers ---

  defp check_can_send(sender_id) do
    if can_send_message?(sender_id) do
      :ok
    else
      {:error, :subscription_required}
    end
  end

  defp notify_new_message(conversation, sender_id, message) do
    participants = conversation["participants"] || []

    recipient_oid =
      Enum.find(participants, fn p -> to_string(p) != to_string(to_oid(sender_id)) end)

    if recipient_oid do
      recipient_id = to_string(recipient_oid)
      content_preview = String.slice(message["content"] || "", 0, 100)

      Koikoi.Notifications.create_notification(
        recipient_id,
        "new_message",
        "新しいメッセージ",
        content_preview,
        %{
          "conversation_id" => to_string(conversation["_id"]),
          "sender_id" => to_string(to_oid(sender_id)),
          "message_id" => to_string(message["_id"])
        }
      )
    end
  end

  defp to_oid(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, oid} -> oid
      :error -> id
    end
  end

  defp to_oid(%BSON.ObjectId{} = oid), do: oid
  defp to_oid(id), do: id
end
