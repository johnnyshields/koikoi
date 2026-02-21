defmodule Koikoi.Social do
  @moduledoc """
  The Social context manages friend connections, matchmaker relationships,
  trust tiers, and invite codes.
  """

  alias Koikoi.Repo

  @connections_collection "connections"
  @users_collection "users"

  @valid_trust_tiers ~w(inner_circle friends verified open)
  @matchmaker_activation_threshold 2

  # --- Friend Management ---

  def send_friend_request(requester_id, recipient_id) do
    with {:ok, requester_oid} <- decode_id(requester_id),
         {:ok, recipient_oid} <- decode_id(recipient_id),
         :ok <- validate_not_self(requester_oid, recipient_oid),
         nil <- find_existing_connection(requester_oid, recipient_oid, "friend") do
      now = DateTime.utc_now()

      document = %{
        requester_id: requester_oid,
        recipient_id: recipient_oid,
        type: "friend",
        trust_tier: "friends",
        status: "pending",
        matchmaker_id: nil,
        subject_id: nil,
        inserted_at: now,
        updated_at: now
      }

      case Repo.insert_one(@connections_collection, document) do
        {:ok, result} ->
          connection = Repo.find_one(@connections_collection, %{_id: result.inserted_id})
          {:ok, connection}

        {:error, reason} ->
          {:error, reason}
      end
    else
      %{} -> {:error, "connection_already_exists"}
      {:error, _} = error -> error
    end
  end

  def accept_friend_request(connection_id, user_id) do
    with {:ok, conn_oid} <- decode_id(connection_id),
         {:ok, user_oid} <- decode_id(user_id),
         connection when not is_nil(connection) <-
           Repo.find_one(@connections_collection, %{
             _id: conn_oid,
             type: "friend",
             status: "pending"
           }),
         :ok <- validate_is_recipient(connection, user_oid) do
      now = DateTime.utc_now()

      Repo.update_one(
        @connections_collection,
        %{_id: conn_oid},
        %{"$set" => %{status: "accepted", updated_at: now}}
      )

      updated = Repo.find_one(@connections_collection, %{_id: conn_oid})
      {:ok, updated}
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def decline_friend_request(connection_id, user_id) do
    with {:ok, conn_oid} <- decode_id(connection_id),
         {:ok, user_oid} <- decode_id(user_id),
         connection when not is_nil(connection) <-
           Repo.find_one(@connections_collection, %{
             _id: conn_oid,
             type: "friend",
             status: "pending"
           }),
         :ok <- validate_is_recipient(connection, user_oid) do
      now = DateTime.utc_now()

      Repo.update_one(
        @connections_collection,
        %{_id: conn_oid},
        %{"$set" => %{status: "declined", updated_at: now}}
      )

      updated = Repo.find_one(@connections_collection, %{_id: conn_oid})
      {:ok, updated}
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def remove_friend(user_id, friend_id) do
    with {:ok, user_oid} <- decode_id(user_id),
         {:ok, friend_oid} <- decode_id(friend_id) do
      filter = %{
        "type" => "friend",
        "status" => "accepted",
        "$or" => [
          %{requester_id: user_oid, recipient_id: friend_oid},
          %{requester_id: friend_oid, recipient_id: user_oid}
        ]
      }

      case Repo.delete_one(@connections_collection, filter) do
        {:ok, %Mongo.DeleteResult{deleted_count: 1}} -> :ok
        {:ok, %Mongo.DeleteResult{deleted_count: 0}} -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def list_friends(user_id, opts \\ []) do
    with {:ok, user_oid} <- decode_id(user_id) do
      page = Keyword.get(opts, :page, 1)
      limit = Keyword.get(opts, :limit, 20)
      skip = (page - 1) * limit

      filter = %{
        "type" => "friend",
        "status" => "accepted",
        "$or" => [
          %{requester_id: user_oid},
          %{recipient_id: user_oid}
        ]
      }

      connections =
        Repo.find(@connections_collection, filter,
          sort: %{updated_at: -1},
          skip: skip,
          limit: limit
        )
        |> Enum.to_list()

      {:ok, connections}
    end
  end

  def list_pending_requests(user_id) do
    with {:ok, user_oid} <- decode_id(user_id) do
      filter = %{
        type: "friend",
        status: "pending",
        recipient_id: user_oid
      }

      requests =
        Repo.find(@connections_collection, filter, sort: %{inserted_at: -1})
        |> Enum.to_list()

      {:ok, requests}
    end
  end

  # --- Matchmaker Management ---

  def invite_matchmaker(user_id, matchmaker_user_id) do
    with {:ok, user_oid} <- decode_id(user_id),
         {:ok, matchmaker_oid} <- decode_id(matchmaker_user_id),
         :ok <- validate_not_self(user_oid, matchmaker_oid),
         nil <- find_existing_matchmaker(user_oid, matchmaker_oid) do
      now = DateTime.utc_now()

      document = %{
        requester_id: user_oid,
        recipient_id: matchmaker_oid,
        type: "matchmaker",
        trust_tier: "verified",
        status: "pending",
        matchmaker_id: matchmaker_oid,
        subject_id: user_oid,
        inserted_at: now,
        updated_at: now
      }

      case Repo.insert_one(@connections_collection, document) do
        {:ok, result} ->
          connection = Repo.find_one(@connections_collection, %{_id: result.inserted_id})
          {:ok, connection}

        {:error, reason} ->
          {:error, reason}
      end
    else
      %{} -> {:error, "matchmaker_connection_already_exists"}
      {:error, _} = error -> error
    end
  end

  def accept_matchmaker_invite(connection_id, user_id) do
    with {:ok, conn_oid} <- decode_id(connection_id),
         {:ok, user_oid} <- decode_id(user_id),
         connection when not is_nil(connection) <-
           Repo.find_one(@connections_collection, %{
             _id: conn_oid,
             type: "matchmaker",
             status: "pending"
           }),
         :ok <- validate_is_recipient(connection, user_oid) do
      now = DateTime.utc_now()

      Repo.update_one(
        @connections_collection,
        %{_id: conn_oid},
        %{"$set" => %{status: "accepted", updated_at: now}}
      )

      updated = Repo.find_one(@connections_collection, %{_id: conn_oid})
      {:ok, updated}
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def decline_matchmaker_invite(connection_id, user_id) do
    with {:ok, conn_oid} <- decode_id(connection_id),
         {:ok, user_oid} <- decode_id(user_id),
         connection when not is_nil(connection) <-
           Repo.find_one(@connections_collection, %{
             _id: conn_oid,
             type: "matchmaker",
             status: "pending"
           }),
         :ok <- validate_is_recipient(connection, user_oid) do
      now = DateTime.utc_now()

      Repo.update_one(
        @connections_collection,
        %{_id: conn_oid},
        %{"$set" => %{status: "declined", updated_at: now}}
      )

      updated = Repo.find_one(@connections_collection, %{_id: conn_oid})
      {:ok, updated}
    else
      nil -> {:error, :not_found}
      {:error, _} = error -> error
    end
  end

  def remove_matchmaker(user_id, matchmaker_id) do
    with {:ok, user_oid} <- decode_id(user_id),
         {:ok, matchmaker_oid} <- decode_id(matchmaker_id) do
      filter = %{
        type: "matchmaker",
        status: "accepted",
        matchmaker_id: matchmaker_oid,
        subject_id: user_oid
      }

      case Repo.delete_one(@connections_collection, filter) do
        {:ok, %Mongo.DeleteResult{deleted_count: 1}} -> :ok
        {:ok, %Mongo.DeleteResult{deleted_count: 0}} -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def list_matchmakers(user_id) do
    with {:ok, user_oid} <- decode_id(user_id) do
      filter = %{
        type: "matchmaker",
        status: "accepted",
        subject_id: user_oid
      }

      matchmakers =
        Repo.find(@connections_collection, filter, sort: %{updated_at: -1})
        |> Enum.to_list()

      {:ok, matchmakers}
    end
  end

  def list_matchmaker_subjects(matchmaker_id) do
    with {:ok, matchmaker_oid} <- decode_id(matchmaker_id) do
      filter = %{
        type: "matchmaker",
        status: "accepted",
        matchmaker_id: matchmaker_oid
      }

      subjects =
        Repo.find(@connections_collection, filter, sort: %{updated_at: -1})
        |> Enum.to_list()

      {:ok, subjects}
    end
  end

  # --- Trust Tier ---

  def get_trust_tier(user_id, other_user_id) do
    with {:ok, user_oid} <- decode_id(user_id),
         {:ok, other_oid} <- decode_id(other_user_id) do
      # Check direct friend connection first
      friend_conn = find_accepted_friend(user_oid, other_oid)

      cond do
        friend_conn != nil ->
          friend_conn["trust_tier"] || "friends"

        has_matchmaker_relationship?(user_oid, other_oid) ->
          "verified"

        true ->
          "open"
      end
    else
      {:error, _} -> "open"
    end
  end

  def update_trust_tier(user_id, friend_id, new_tier) when new_tier in @valid_trust_tiers do
    with {:ok, user_oid} <- decode_id(user_id),
         {:ok, friend_oid} <- decode_id(friend_id) do
      filter = %{
        "type" => "friend",
        "status" => "accepted",
        "$or" => [
          %{requester_id: user_oid, recipient_id: friend_oid},
          %{requester_id: friend_oid, recipient_id: user_oid}
        ]
      }

      case Repo.find_one(@connections_collection, filter) do
        nil ->
          {:error, :not_found}

        connection ->
          now = DateTime.utc_now()

          Repo.update_one(
            @connections_collection,
            %{_id: connection["_id"]},
            %{"$set" => %{trust_tier: new_tier, updated_at: now}}
          )

          updated = Repo.find_one(@connections_collection, %{_id: connection["_id"]})
          {:ok, updated}
      end
    end
  end

  def update_trust_tier(_user_id, _friend_id, _new_tier) do
    {:error, "invalid_trust_tier"}
  end

  # --- Invite Codes ---

  def redeem_invite_code(user_id, invite_code) do
    with {:ok, user_oid} <- decode_id(user_id),
         inviter when not is_nil(inviter) <-
           Repo.find_one(@users_collection, %{invite_code: invite_code}) do
      inviter_oid = inviter["_id"]

      if inviter_oid == user_oid do
        {:error, "cannot_redeem_own_code"}
      else
        # Check if already connected
        case find_existing_connection(user_oid, inviter_oid, "friend") do
          nil ->
            # Create friend request from the code redeemer to the inviter
            now = DateTime.utc_now()

            document = %{
              requester_id: user_oid,
              recipient_id: inviter_oid,
              type: "friend",
              trust_tier: "friends",
              status: "pending",
              matchmaker_id: nil,
              subject_id: nil,
              inserted_at: now,
              updated_at: now
            }

            case Repo.insert_one(@connections_collection, document) do
              {:ok, result} ->
                # Increment inviter's matchmaker_invites_sent counter
                Repo.update_one(
                  @users_collection,
                  %{_id: inviter_oid},
                  %{
                    "$inc" => %{matchmaker_invites_sent: 1},
                    "$set" => %{updated_at: now}
                  }
                )

                connection = Repo.find_one(@connections_collection, %{_id: result.inserted_id})
                {:ok, connection}

              {:error, reason} ->
                {:error, reason}
            end

          %{} ->
            {:error, "already_connected"}
        end
      end
    else
      nil -> {:error, "invalid_invite_code"}
      {:error, _} = error -> error
    end
  end

  def get_invite_stats(user_id) do
    with {:ok, user_oid} <- decode_id(user_id) do
      case Repo.find_one(@users_collection, %{_id: user_oid}) do
        nil ->
          {:error, :not_found}

        user ->
          {:ok,
           %{
             invite_code: user["invite_code"],
             invites_sent: user["matchmaker_invites_sent"] || 0
           }}
      end
    end
  end

  # --- Activation Check ---

  def is_matchmaking_active?(user_id) do
    count = get_matchmaker_count(user_id)
    count >= @matchmaker_activation_threshold
  end

  def get_matchmaker_count(user_id) do
    case decode_id(user_id) do
      {:ok, user_oid} ->
        Repo.count_documents(@connections_collection, %{
          type: "matchmaker",
          status: "accepted",
          subject_id: user_oid
        })

      {:error, _} ->
        0
    end
  end

  # --- Matchmaker Permissions ---

  def get_matchable_users(matchmaker_id) do
    with {:ok, matchmaker_oid} <- decode_id(matchmaker_id) do
      filter = %{
        type: "matchmaker",
        status: "accepted",
        matchmaker_id: matchmaker_oid
      }

      user_ids =
        Repo.find(@connections_collection, filter)
        |> Enum.map(fn conn -> to_string(conn["subject_id"]) end)

      {:ok, user_ids}
    end
  end

  def can_matchmake?(matchmaker_id, user_id) do
    case {decode_id(matchmaker_id), decode_id(user_id)} do
      {{:ok, matchmaker_oid}, {:ok, user_oid}} ->
        filter = %{
          type: "matchmaker",
          status: "accepted",
          matchmaker_id: matchmaker_oid,
          subject_id: user_oid
        }

        Repo.count_documents(@connections_collection, filter) > 0

      _ ->
        false
    end
  end

  # --- Private Helpers ---

  defp decode_id(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, oid} -> {:ok, oid}
      :error -> {:error, "invalid_id"}
    end
  end

  defp decode_id(%BSON.ObjectId{} = oid), do: {:ok, oid}
  defp decode_id(_), do: {:error, "invalid_id"}

  defp validate_not_self(id_a, id_b) do
    if id_a == id_b, do: {:error, "cannot_connect_to_self"}, else: :ok
  end

  defp validate_is_recipient(connection, user_oid) do
    if connection["recipient_id"] == user_oid do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp find_existing_connection(user_a_oid, user_b_oid, type) do
    filter = %{
      "type" => type,
      "status" => %{"$in" => ["pending", "accepted"]},
      "$or" => [
        %{requester_id: user_a_oid, recipient_id: user_b_oid},
        %{requester_id: user_b_oid, recipient_id: user_a_oid}
      ]
    }

    Repo.find_one(@connections_collection, filter)
  end

  defp find_existing_matchmaker(subject_oid, matchmaker_oid) do
    Repo.find_one(@connections_collection, %{
      "type" => "matchmaker",
      "status" => %{"$in" => ["pending", "accepted"]},
      "matchmaker_id" => matchmaker_oid,
      "subject_id" => subject_oid
    })
  end

  defp find_accepted_friend(user_oid, other_oid) do
    Repo.find_one(@connections_collection, %{
      "type" => "friend",
      "status" => "accepted",
      "$or" => [
        %{requester_id: user_oid, recipient_id: other_oid},
        %{requester_id: other_oid, recipient_id: user_oid}
      ]
    })
  end

  defp has_matchmaker_relationship?(user_oid, other_oid) do
    filter = %{
      "type" => "matchmaker",
      "status" => "accepted",
      "$or" => [
        %{matchmaker_id: user_oid, subject_id: other_oid},
        %{matchmaker_id: other_oid, subject_id: user_oid}
      ]
    }

    Repo.count_documents(@connections_collection, filter) > 0
  end
end
