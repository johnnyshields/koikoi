defmodule Koikoi.Chat do
  @moduledoc "The Chat context manages conversations and messages."

  alias Koikoi.{Repo, Accounts, Social}

  @conversations_collection "conversations"
  @messages_collection "messages"

  # --- Conversations ---

  def create_conversation(match_id, person_a_id, person_b_id) do
    now = DateTime.utc_now()

    document = %{
      type: "dm",
      match_id: to_oid(match_id),
      name: nil,
      admin_ids: nil,
      participants: [to_oid(person_a_id), to_oid(person_b_id)],
      status: "active",
      last_message_at: nil,
      expires_at: nil,
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

  def get_or_create_dm(user_a_id, user_b_id) do
    if Social.are_friends?(user_a_id, user_b_id) do
      user_a_oid = to_oid(user_a_id)
      user_b_oid = to_oid(user_b_id)
      # Canonical ordering for consistent queries
      [p1, p2] = Enum.sort([user_a_oid, user_b_oid], fn a, b -> to_string(a) < to_string(b) end)

      # Check if DM already exists
      existing =
        Repo.find_one(@conversations_collection, %{
          type: "dm",
          participants: %{"$all" => [p1, p2], "$size" => 2}
        })

      case existing do
        nil ->
          now = DateTime.utc_now()

          document = %{
            type: "dm",
            match_id: nil,
            name: nil,
            admin_ids: nil,
            participants: [p1, p2],
            status: "active",
            last_message_at: nil,
            expires_at: nil,
            inserted_at: now,
            updated_at: now
          }

          case Repo.insert_one(@conversations_collection, document) do
            {:ok, result} ->
              conversation =
                Repo.find_one(@conversations_collection, %{_id: result.inserted_id})

              {:ok, conversation}

            {:error, reason} ->
              {:error, reason}
          end

        conversation ->
          {:ok, conversation}
      end
    else
      {:error, :not_friends}
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

  # --- Group Chats ---

  def create_group(creator_id, name, member_ids) do
    if is_nil(name) or String.trim(name) == "" do
      {:error, :name_required}
    else
      case validate_all_friends(creator_id, member_ids) do
        :ok ->
          creator_oid = to_oid(creator_id)
          member_oids = Enum.map(member_ids, &to_oid/1)
          all_participants = [creator_oid | member_oids] |> Enum.uniq_by(&to_string/1)
          now = DateTime.utc_now()

          document = %{
            type: "group",
            match_id: nil,
            name: String.trim(name),
            admin_ids: [creator_oid],
            participants: all_participants,
            status: "active",
            last_message_at: nil,
            expires_at: nil,
            inserted_at: now,
            updated_at: now
          }

          case Repo.insert_one(@conversations_collection, document) do
            {:ok, result} ->
              conversation =
                Repo.find_one(@conversations_collection, %{_id: result.inserted_id})

              insert_system_message(result.inserted_id, "グループが作成されました")
              {:ok, conversation}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  def create_goukon(creator_id, name, member_ids, expires_in_hours) do
    if is_nil(name) or String.trim(name) == "" do
      {:error, :name_required}
    else
      case validate_all_friends(creator_id, member_ids) do
        :ok ->
          creator_oid = to_oid(creator_id)
          member_oids = Enum.map(member_ids, &to_oid/1)
          all_participants = [creator_oid | member_oids] |> Enum.uniq_by(&to_string/1)
          now = DateTime.utc_now()
          expires_at = DateTime.add(now, expires_in_hours * 3600, :second)

          document = %{
            type: "goukon",
            match_id: nil,
            name: String.trim(name),
            admin_ids: [creator_oid],
            participants: all_participants,
            status: "active",
            last_message_at: nil,
            expires_at: expires_at,
            inserted_at: now,
            updated_at: now
          }

          case Repo.insert_one(@conversations_collection, document) do
            {:ok, result} ->
              conversation =
                Repo.find_one(@conversations_collection, %{_id: result.inserted_id})

              insert_system_message(result.inserted_id, "合コングループが作成されました")
              {:ok, conversation}

            {:error, reason} ->
              {:error, reason}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  def add_members(conversation_id, admin_id, new_member_ids) do
    admin_oid = to_oid(admin_id)

    with {:ok, conversation} <- get_conversation(conversation_id, admin_id),
         :ok <- check_is_admin(conversation, admin_oid),
         :ok <- validate_all_friends(admin_id, new_member_ids) do
      conv_oid = to_oid(conversation_id)
      new_member_oids = Enum.map(new_member_ids, &to_oid/1)
      existing_participants = Enum.map(conversation["participants"] || [], &to_string/1)

      actually_new =
        Enum.filter(new_member_oids, fn oid ->
          to_string(oid) not in existing_participants
        end)

      if actually_new == [] do
        {:ok, 0}
      else
        now = DateTime.utc_now()

        Repo.update_one(
          @conversations_collection,
          %{_id: conv_oid},
          %{
            "$push" => %{participants: %{"$each" => actually_new}},
            "$set" => %{updated_at: now}
          }
        )

        Enum.each(actually_new, fn _oid ->
          insert_system_message(conv_oid, "新しいメンバーが参加しました")
        end)

        {:ok, length(actually_new)}
      end
    end
  end

  def remove_member(conversation_id, admin_id, member_id) do
    admin_oid = to_oid(admin_id)
    member_oid = to_oid(member_id)

    with {:ok, conversation} <- get_conversation(conversation_id, admin_id),
         :ok <- check_is_admin(conversation, admin_oid) do
      if to_string(admin_oid) == to_string(member_oid) do
        {:error, :cannot_remove_self}
      else
        conv_oid = to_oid(conversation_id)
        now = DateTime.utc_now()

        Repo.update_one(
          @conversations_collection,
          %{_id: conv_oid},
          %{
            "$pull" => %{participants: member_oid},
            "$set" => %{updated_at: now}
          }
        )

        insert_system_message(conv_oid, "メンバーが退出しました")
        :ok
      end
    end
  end

  def leave_group(conversation_id, user_id) do
    conv_oid = to_oid(conversation_id)
    user_oid = to_oid(user_id)

    with {:ok, conversation} <- get_conversation(conversation_id, user_id) do
      now = DateTime.utc_now()

      # Remove from participants
      Repo.update_one(
        @conversations_collection,
        %{_id: conv_oid},
        %{
          "$pull" => %{participants: user_oid},
          "$set" => %{updated_at: now}
        }
      )

      # If was admin, remove from admin_ids too
      admin_ids = conversation["admin_ids"] || []
      admin_strings = Enum.map(admin_ids, &to_string/1)

      if to_string(user_oid) in admin_strings do
        Repo.update_one(
          @conversations_collection,
          %{_id: conv_oid},
          %{"$pull" => %{admin_ids: user_oid}}
        )

        # Promote next participant if no admins left
        updated_conv = Repo.find_one(@conversations_collection, %{_id: conv_oid})
        remaining_admins = updated_conv["admin_ids"] || []
        remaining_participants = updated_conv["participants"] || []

        if remaining_admins == [] and remaining_participants != [] do
          new_admin = hd(remaining_participants)

          Repo.update_one(
            @conversations_collection,
            %{_id: conv_oid},
            %{"$push" => %{admin_ids: new_admin}}
          )
        end
      end

      # Archive if no participants left
      updated = Repo.find_one(@conversations_collection, %{_id: conv_oid})

      if (updated["participants"] || []) == [] do
        Repo.update_one(
          @conversations_collection,
          %{_id: conv_oid},
          %{"$set" => %{status: "archived", updated_at: now}}
        )
      end

      insert_system_message(conv_oid, "メンバーが退出しました")
      :ok
    end
  end

  def update_group(conversation_id, admin_id, attrs) do
    admin_oid = to_oid(admin_id)

    with {:ok, conversation} <- get_conversation(conversation_id, admin_id),
         :ok <- check_is_admin(conversation, admin_oid) do
      conv_oid = to_oid(conversation_id)
      now = DateTime.utc_now()
      updates = %{updated_at: now}

      updates =
        if attrs["name"], do: Map.put(updates, :name, String.trim(attrs["name"])), else: updates

      Repo.update_one(
        @conversations_collection,
        %{_id: conv_oid},
        %{"$set" => updates}
      )

      updated = Repo.find_one(@conversations_collection, %{_id: conv_oid})
      {:ok, updated}
    end
  end

  def list_members(conversation_id, user_id) do
    with {:ok, conversation} <- get_conversation(conversation_id, user_id) do
      participants = conversation["participants"] || []
      admin_ids = conversation["admin_ids"] || []
      admin_strings = Enum.map(admin_ids, &to_string/1)

      members =
        Enum.map(participants, fn p_oid ->
          user_id_str = to_string(p_oid)

          profile =
            case Koikoi.Profiles.get_profile(user_id_str) do
              {:ok, profile} -> profile
              _ -> nil
            end

          photos = if profile, do: profile["photos"] || [], else: []
          primary_photo = Enum.find(photos, fn p -> p["is_primary"] || p[:is_primary] end)

          %{
            user_id: user_id_str,
            nickname: if(profile, do: profile["nickname"], else: nil),
            primary_photo: primary_photo,
            is_admin: user_id_str in admin_strings
          }
        end)

      {:ok, members}
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
    sender_str = to_string(to_oid(sender_id))

    recipients = Enum.filter(participants, fn p -> to_string(p) != sender_str end)

    content_preview = String.slice(message["content"] || "", 0, 100)

    Enum.each(recipients, fn recipient_oid ->
      recipient_id = to_string(recipient_oid)

      Koikoi.Notifications.create_notification(
        recipient_id,
        "new_message",
        "新しいメッセージ",
        content_preview,
        %{
          "conversation_id" => to_string(conversation["_id"]),
          "sender_id" => sender_str,
          "message_id" => to_string(message["_id"])
        }
      )
    end)
  end

  defp validate_all_friends(user_id, member_ids) do
    all_friends? =
      Enum.all?(member_ids, fn mid ->
        Social.are_friends?(user_id, mid)
      end)

    if all_friends?, do: :ok, else: {:error, :not_friends_with_all}
  end

  defp check_is_admin(conversation, user_oid) do
    admin_ids = conversation["admin_ids"] || []
    admin_strings = Enum.map(admin_ids, &to_string/1)

    if to_string(user_oid) in admin_strings do
      :ok
    else
      {:error, :not_admin}
    end
  end

  defp insert_system_message(conversation_id, content) do
    now = DateTime.utc_now()
    conv_oid = if is_binary(conversation_id), do: to_oid(conversation_id), else: conversation_id

    message = %{
      conversation_id: conv_oid,
      sender_id: nil,
      content: content,
      message_type: "system",
      read_at: nil,
      inserted_at: now
    }

    Repo.insert_one(@messages_collection, message)

    Repo.update_one(
      @conversations_collection,
      %{_id: conv_oid},
      %{"$set" => %{last_message_at: now, updated_at: now}}
    )
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
