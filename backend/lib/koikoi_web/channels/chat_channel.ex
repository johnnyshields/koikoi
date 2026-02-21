defmodule KoikoiWeb.ChatChannel do
  use KoikoiWeb, :channel

  alias Koikoi.Chat

  # Join chat:conversation_id - verify user is participant
  def join("chat:" <> conversation_id, _payload, socket) do
    user_id = socket.assigns.user_id

    case Chat.get_conversation(conversation_id, user_id) do
      {:ok, _conversation} ->
        # Mark messages as read on join
        Chat.mark_read(conversation_id, user_id)

        {:ok, %{conversation_id: conversation_id},
         assign(socket, :conversation_id, conversation_id)}

      {:error, _} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  # Handle incoming messages
  def handle_in("new_message", %{"content" => content} = payload, socket) do
    user_id = socket.assigns.user_id
    conversation_id = socket.assigns.conversation_id

    attrs = %{
      "content" => content,
      "message_type" => Map.get(payload, "message_type", "text")
    }

    case Chat.send_message(conversation_id, user_id, attrs) do
      {:ok, message} ->
        broadcast!(socket, "new_message", serialize_message(message))
        {:reply, {:ok, serialize_message(message)}, socket}

      {:error, :subscription_required} ->
        {:reply, {:error, %{reason: "subscription_required"}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: to_string(reason)}}, socket}
    end
  end

  # Handle typing indicator
  def handle_in("typing", _payload, socket) do
    user_id = socket.assigns.user_id
    broadcast_from!(socket, "typing", %{user_id: user_id})
    {:noreply, socket}
  end

  # Handle mark_read
  def handle_in("mark_read", _payload, socket) do
    user_id = socket.assigns.user_id
    conversation_id = socket.assigns.conversation_id
    Chat.mark_read(conversation_id, user_id)
    broadcast_from!(socket, "messages_read", %{user_id: user_id})
    {:reply, :ok, socket}
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
end
