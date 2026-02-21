defmodule Koikoi.Notifications do
  @moduledoc "The Notifications context manages user notifications."

  alias Koikoi.Repo

  @collection "notifications"

  def create_notification(user_id, type, title, body, data \\ %{}) do
    now = DateTime.utc_now()

    document = %{
      user_id: to_oid(user_id),
      type: type,
      title: title,
      body: body,
      data: data,
      read: false,
      inserted_at: now
    }

    case Repo.insert_one(@collection, document) do
      {:ok, result} ->
        notification = Repo.find_one(@collection, %{_id: result.inserted_id})

        # Broadcast via PubSub
        Phoenix.PubSub.broadcast(
          Koikoi.PubSub,
          "notifications:#{user_id}",
          {:new_notification, notification}
        )

        {:ok, notification}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_notifications(user_id, opts \\ []) do
    user_oid = to_oid(user_id)
    page = Keyword.get(opts, :page, 1)
    limit = Keyword.get(opts, :limit, 20)
    unread_only = Keyword.get(opts, :unread_only, false)
    skip = (page - 1) * limit

    filter =
      if unread_only do
        %{user_id: user_oid, read: false}
      else
        %{user_id: user_oid}
      end

    notifications =
      Repo.find(
        @collection,
        filter,
        sort: %{inserted_at: -1},
        skip: skip,
        limit: limit
      )
      |> Enum.to_list()

    {:ok, notifications}
  end

  def mark_read(notification_id, user_id) do
    notif_oid = to_oid(notification_id)
    user_oid = to_oid(user_id)

    case Repo.find_one(@collection, %{_id: notif_oid, user_id: user_oid}) do
      nil ->
        {:error, :not_found}

      _notification ->
        Repo.update_one(
          @collection,
          %{_id: notif_oid},
          %{"$set" => %{read: true}}
        )

        {:ok, Repo.find_one(@collection, %{_id: notif_oid})}
    end
  end

  def mark_all_read(user_id) do
    user_oid = to_oid(user_id)

    Repo.update_many(
      @collection,
      %{user_id: user_oid, read: false},
      %{"$set" => %{read: true}}
    )

    :ok
  end

  def get_unread_count(user_id) do
    user_oid = to_oid(user_id)
    Repo.count_documents(@collection, %{user_id: user_oid, read: false})
  end

  # --- Helpers ---

  defp to_oid(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, oid} -> oid
      :error -> id
    end
  end

  defp to_oid(%BSON.ObjectId{} = oid), do: oid
  defp to_oid(id), do: id
end
