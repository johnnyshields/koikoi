defmodule KoikoiWeb.ChatController do
  use KoikoiWeb, :controller

  alias Koikoi.Chat

  action_fallback KoikoiWeb.FallbackController

  # GET /api/v1/conversations
  def list_conversations(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    opts = [
      page: parse_int(params["page"], 1),
      limit: parse_int(params["limit"], 20)
    ]

    with {:ok, conversations} <- Chat.list_conversations(user_id, opts) do
      json(conn, %{conversations: Enum.map(conversations, &serialize_conversation/1)})
    end
  end

  # GET /api/v1/conversations/:id
  def get_conversation(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    with {:ok, conversation} <- Chat.get_conversation(id, user_id) do
      json(conn, %{conversation: serialize_conversation(conversation)})
    end
  end

  # GET /api/v1/conversations/:id/messages
  def list_messages(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    opts = [
      before: params["before"],
      limit: parse_int(params["limit"], 50)
    ]

    with {:ok, messages} <- Chat.list_messages(id, user_id, opts) do
      json(conn, %{messages: Enum.map(messages, &serialize_message/1)})
    end
  end

  # POST /api/v1/conversations/:id/messages
  def send_message(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    attrs = %{
      "content" => params["content"],
      "message_type" => params["message_type"] || "text"
    }

    with {:ok, message} <- Chat.send_message(id, user_id, attrs) do
      conn
      |> put_status(:created)
      |> json(%{message: serialize_message(message)})
    end
  end

  # POST /api/v1/conversations/:id/read
  def mark_read(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    with {:ok, _conversation} <- Chat.get_conversation(id, user_id) do
      Chat.mark_read(id, user_id)
      json(conn, %{status: "ok"})
    end
  end

  # GET /api/v1/chat/unread-count
  def unread_count(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    with {:ok, count} <- Chat.get_unread_count(user_id) do
      json(conn, %{unread_count: count})
    end
  end

  # POST /api/v1/conversations/dm
  def create_dm(conn, %{"friend_id" => friend_id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Chat.get_or_create_dm(user_id, friend_id) do
      {:ok, conversation} ->
        conn
        |> put_status(:created)
        |> json(%{conversation: serialize_conversation(conversation)})

      {:error, :not_friends} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "not_friends"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  # POST /api/v1/conversations/group
  def create_group(conn, %{"name" => name, "member_ids" => member_ids}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Chat.create_group(user_id, name, member_ids) do
      {:ok, conversation} ->
        conn
        |> put_status(:created)
        |> json(%{conversation: serialize_conversation(conversation)})

      {:error, :name_required} ->
        conn |> put_status(:bad_request) |> json(%{error: "name_required"})

      {:error, :not_friends_with_all} ->
        conn |> put_status(:bad_request) |> json(%{error: "not_friends_with_all"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # POST /api/v1/conversations/goukon
  def create_goukon(conn, %{"name" => name, "member_ids" => member_ids} = params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])
    expires_in_hours = params["expires_in_hours"] || 24

    case Chat.create_goukon(user_id, name, member_ids, expires_in_hours) do
      {:ok, conversation} ->
        conn
        |> put_status(:created)
        |> json(%{conversation: serialize_conversation(conversation)})

      {:error, :name_required} ->
        conn |> put_status(:bad_request) |> json(%{error: "name_required"})

      {:error, :not_friends_with_all} ->
        conn |> put_status(:bad_request) |> json(%{error: "not_friends_with_all"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # POST /api/v1/conversations/:id/members
  def add_members(conn, %{"id" => id, "member_ids" => member_ids}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Chat.add_members(id, user_id, member_ids) do
      {:ok, added} ->
        json(conn, %{status: "ok", added: added})

      {:error, :not_admin} ->
        conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # DELETE /api/v1/conversations/:id/members/:user_id
  def remove_member(conn, %{"id" => id, "user_id" => member_id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Chat.remove_member(id, user_id, member_id) do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_admin} ->
        conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # POST /api/v1/conversations/:id/leave
  def leave_group(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Chat.leave_group(id, user_id) do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # PUT /api/v1/conversations/:id
  def update_group(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Chat.update_group(id, user_id, params) do
      {:ok, conversation} ->
        json(conn, %{conversation: serialize_conversation(conversation)})

      {:error, :not_admin} ->
        conn |> put_status(:forbidden) |> json(%{error: "not_admin"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # GET /api/v1/conversations/:id/members
  def list_members(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Chat.list_members(id, user_id) do
      {:ok, members} ->
        json(conn, %{members: Enum.map(members, &serialize_member/1)})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # --- Private Helpers ---

  defp serialize_conversation(conv) do
    %{
      id: to_string(conv["_id"]),
      type: conv["type"] || "dm",
      match_id: maybe_to_string(conv["match_id"]),
      name: conv["name"],
      admin_ids: serialize_admin_ids(conv["admin_ids"]),
      participants: Enum.map(conv["participants"] || [], &to_string/1),
      status: conv["status"],
      last_message_at: conv["last_message_at"],
      last_message: serialize_last_message(conv["last_message"]),
      expires_at: conv["expires_at"],
      inserted_at: conv["inserted_at"],
      updated_at: conv["updated_at"]
    }
  end

  defp serialize_admin_ids(nil), do: nil
  defp serialize_admin_ids(ids), do: Enum.map(ids, &to_string/1)

  defp serialize_last_message(nil), do: nil

  defp serialize_last_message(msg) do
    serialize_message(msg)
  end

  defp serialize_message(msg) do
    %{
      id: to_string(msg["_id"]),
      conversation_id: to_string(msg["conversation_id"]),
      sender_id: maybe_to_string(msg["sender_id"]),
      content: msg["content"],
      message_type: msg["message_type"] || "text",
      read_at: msg["read_at"],
      inserted_at: msg["inserted_at"]
    }
  end

  defp serialize_member(member) do
    %{
      user_id: member.user_id,
      nickname: member.nickname,
      primary_photo: member.primary_photo,
      is_admin: member.is_admin
    }
  end

  defp maybe_to_string(nil), do: nil
  defp maybe_to_string(val), do: to_string(val)

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> max(int, 1)
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: max(val, 1)
  defp parse_int(_, default), do: default
end
