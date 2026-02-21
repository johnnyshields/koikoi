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

  # --- Private Helpers ---

  defp serialize_conversation(conv) do
    %{
      id: to_string(conv["_id"]),
      match_id: maybe_to_string(conv["match_id"]),
      participants: Enum.map(conv["participants"] || [], &to_string/1),
      status: conv["status"],
      last_message_at: conv["last_message_at"],
      last_message: serialize_last_message(conv["last_message"]),
      inserted_at: conv["inserted_at"],
      updated_at: conv["updated_at"]
    }
  end

  defp serialize_last_message(nil), do: nil

  defp serialize_last_message(msg) do
    serialize_message(msg)
  end

  defp serialize_message(msg) do
    %{
      id: to_string(msg["_id"]),
      conversation_id: to_string(msg["conversation_id"]),
      sender_id: to_string(msg["sender_id"]),
      content: msg["content"],
      message_type: msg["message_type"],
      read_at: msg["read_at"],
      inserted_at: msg["inserted_at"]
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
