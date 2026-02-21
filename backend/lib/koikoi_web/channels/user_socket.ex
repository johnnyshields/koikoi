defmodule KoikoiWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", KoikoiWeb.ChatChannel
  channel "notifications:*", KoikoiWeb.NotificationChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Koikoi.Accounts.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case Koikoi.Accounts.Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            {:ok, assign(socket, :user_id, to_string(user["_id"]))}

          {:error, _} ->
            :error
        end

      {:error, _} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
