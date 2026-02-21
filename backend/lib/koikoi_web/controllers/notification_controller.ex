defmodule KoikoiWeb.NotificationController do
  use KoikoiWeb, :controller

  alias Koikoi.Notifications

  action_fallback KoikoiWeb.FallbackController

  # GET /api/v1/notifications
  def list_notifications(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    opts = [
      page: parse_int(params["page"], 1),
      limit: parse_int(params["limit"], 20),
      unread_only: params["unread_only"] == "true"
    ]

    with {:ok, notifications} <- Notifications.list_notifications(user_id, opts) do
      json(conn, %{notifications: Enum.map(notifications, &serialize_notification/1)})
    end
  end

  # POST /api/v1/notifications/:id/read
  def mark_read(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    with {:ok, notification} <- Notifications.mark_read(id, user_id) do
      json(conn, %{notification: serialize_notification(notification)})
    end
  end

  # POST /api/v1/notifications/read-all
  def mark_all_read(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    Notifications.mark_all_read(user_id)
    json(conn, %{status: "ok"})
  end

  # GET /api/v1/notifications/unread-count
  def unread_count(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    count = Notifications.get_unread_count(user_id)
    json(conn, %{unread_count: count})
  end

  # --- Private Helpers ---

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
