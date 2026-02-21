defmodule KoikoiWeb.SocialController do
  use KoikoiWeb, :controller

  alias Koikoi.Social

  action_fallback KoikoiWeb.FallbackController

  # --- Friends ---

  def send_friend_request(conn, %{"user_id" => recipient_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    requester_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.send_friend_request(requester_id, recipient_id) do
      conn
      |> put_status(:created)
      |> json(%{connection: serialize_connection(connection)})
    end
  end

  def accept_friend_request(conn, %{"connection_id" => connection_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.accept_friend_request(connection_id, user_id) do
      json(conn, %{connection: serialize_connection(connection)})
    end
  end

  def decline_friend_request(conn, %{"connection_id" => connection_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.decline_friend_request(connection_id, user_id) do
      json(conn, %{connection: serialize_connection(connection)})
    end
  end

  def remove_friend(conn, %{"friend_id" => friend_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with :ok <- Social.remove_friend(user_id, friend_id) do
      json(conn, %{message: "friend_removed"})
    end
  end

  def list_friends(conn, params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    page = parse_int(params["page"], 1)
    limit = parse_int(params["limit"], 20)

    with {:ok, connections} <- Social.list_friends(user_id, page: page, limit: limit) do
      json(conn, %{connections: Enum.map(connections, &serialize_connection/1)})
    end
  end

  def list_pending_requests(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, requests} <- Social.list_pending_requests(user_id) do
      json(conn, %{connections: Enum.map(requests, &serialize_connection/1)})
    end
  end

  # --- Matchmakers ---

  def invite_matchmaker(conn, %{"user_id" => matchmaker_user_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.invite_matchmaker(user_id, matchmaker_user_id) do
      conn
      |> put_status(:created)
      |> json(%{connection: serialize_connection(connection)})
    end
  end

  def accept_matchmaker_invite(conn, %{"connection_id" => connection_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.accept_matchmaker_invite(connection_id, user_id) do
      json(conn, %{connection: serialize_connection(connection)})
    end
  end

  def decline_matchmaker_invite(conn, %{"connection_id" => connection_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.decline_matchmaker_invite(connection_id, user_id) do
      json(conn, %{connection: serialize_connection(connection)})
    end
  end

  def remove_matchmaker(conn, %{"matchmaker_id" => matchmaker_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with :ok <- Social.remove_matchmaker(user_id, matchmaker_id) do
      json(conn, %{message: "matchmaker_removed"})
    end
  end

  def list_matchmakers(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, matchmakers} <- Social.list_matchmakers(user_id) do
      json(conn, %{connections: Enum.map(matchmakers, &serialize_connection/1)})
    end
  end

  def list_matchmaker_subjects(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    matchmaker_id = to_string(current_user["_id"])

    with {:ok, subjects} <- Social.list_matchmaker_subjects(matchmaker_id) do
      json(conn, %{connections: Enum.map(subjects, &serialize_connection/1)})
    end
  end

  # --- Trust Tier ---

  def update_trust_tier(conn, %{"friend_id" => friend_id, "tier" => tier}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.update_trust_tier(user_id, friend_id, tier) do
      json(conn, %{connection: serialize_connection(connection)})
    end
  end

  # --- Invites ---

  def redeem_invite_code(conn, %{"code" => code}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, connection} <- Social.redeem_invite_code(user_id, code) do
      conn
      |> put_status(:created)
      |> json(%{connection: serialize_connection(connection)})
    end
  end

  def get_invite_stats(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, stats} <- Social.get_invite_stats(user_id) do
      json(conn, %{stats: stats})
    end
  end

  # --- Social Status ---

  def matchmaking_status(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    active = Social.is_matchmaking_active?(user_id)
    matchmaker_count = Social.get_matchmaker_count(user_id)

    json(conn, %{
      matchmaking_active: active,
      matchmaker_count: matchmaker_count,
      matchmakers_required: 2
    })
  end

  # --- Private Helpers ---

  defp serialize_connection(connection) do
    %{
      id: to_string(connection["_id"]),
      requester_id: to_string(connection["requester_id"]),
      recipient_id: to_string(connection["recipient_id"]),
      type: connection["type"],
      trust_tier: connection["trust_tier"],
      status: connection["status"],
      matchmaker_id: maybe_to_string(connection["matchmaker_id"]),
      subject_id: maybe_to_string(connection["subject_id"]),
      inserted_at: connection["inserted_at"],
      updated_at: connection["updated_at"]
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
