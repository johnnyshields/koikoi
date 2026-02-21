defmodule KoikoiWeb.NotificationChannel do
  use KoikoiWeb, :channel

  alias Koikoi.Notifications

  # Join notifications:user_id - verify it's the same user
  def join("notifications:" <> user_id, _payload, socket) do
    if socket.assigns.user_id == user_id do
      # Subscribe to PubSub for this user
      Phoenix.PubSub.subscribe(Koikoi.PubSub, "notifications:#{user_id}")

      unread_count = Notifications.get_unread_count(user_id)
      {:ok, %{unread_count: unread_count}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Handle PubSub broadcasts (from Notifications context)
  def handle_info({:new_notification, notification}, socket) do
    push(socket, "new_notification", serialize_notification(notification))
    {:noreply, socket}
  end

  # Handle mark_read from client
  def handle_in("mark_read", %{"notification_id" => id}, socket) do
    user_id = socket.assigns.user_id
    Notifications.mark_read(id, user_id)
    {:reply, :ok, socket}
  end

  def handle_in("mark_all_read", _payload, socket) do
    user_id = socket.assigns.user_id
    Notifications.mark_all_read(user_id)
    {:reply, :ok, socket}
  end

  defp serialize_notification(notif) do
    %{
      id: to_string(notif["_id"]),
      type: notif["type"],
      title: notif["title"],
      body: notif["body"],
      data: notif["data"],
      read: notif["read"],
      inserted_at: notif["inserted_at"]
    }
  end
end
