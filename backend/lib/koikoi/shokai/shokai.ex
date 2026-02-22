defmodule Koikoi.Shokai do
  @moduledoc "The Shokai context manages matchmaker introductions (紹介)."

  alias Koikoi.{Repo, Social, Profiles}

  @shokais_collection "shokais"
  @expiry_hours 72

  def create_shokai(matchmaker_id, person_a_id, person_b_id, opts \\ %{}) do
    with :ok <- validate_friends_with_both(matchmaker_id, person_a_id, person_b_id),
         :ok <- validate_no_active_shokai(person_a_id, person_b_id) do
      matchmaker_oid = to_oid(matchmaker_id)
      person_a_oid = to_oid(person_a_id)
      person_b_oid = to_oid(person_b_id)

      # Canonical ordering
      {pa_oid, pb_oid} = canonical_pair(person_a_oid, person_b_oid)

      # Calculate compatibility hints
      shared_tags = compute_shared_tags(person_a_id, person_b_id)

      now = DateTime.utc_now()
      expires_at = DateTime.add(now, @expiry_hours * 3600, :second)

      source_conv_id =
        if opts["source_conversation_id"],
          do: to_oid(opts["source_conversation_id"]),
          else: nil

      document = %{
        matchmaker_id: matchmaker_oid,
        person_a_id: pa_oid,
        person_b_id: pb_oid,
        person_a_response: "pending",
        person_b_response: "pending",
        matchmaker_note: opts["note"],
        compatibility_hints: %{
          shared_tags: shared_tags,
          score: nil
        },
        status: "pending",
        result_conversation_id: nil,
        source_conversation_id: source_conv_id,
        expires_at: expires_at,
        inserted_at: now,
        updated_at: now
      }

      case Repo.insert_one(@shokais_collection, document) do
        {:ok, result} ->
          shokai = Repo.find_one(@shokais_collection, %{_id: result.inserted_id})
          notify_shokai_created(shokai, matchmaker_id)
          {:ok, shokai}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def respond_to_shokai(shokai_id, user_id, response) when response in ["accepted", "declined"] do
    shokai_oid = to_oid(shokai_id)
    user_oid = to_oid(user_id)
    user_str = to_string(user_oid)

    case Repo.find_one(@shokais_collection, %{_id: shokai_oid}) do
      nil ->
        {:error, :not_found}

      shokai ->
        pa_str = to_string(shokai["person_a_id"])
        pb_str = to_string(shokai["person_b_id"])

        cond do
          shokai["status"] != "pending" ->
            {:error, :not_pending}

          user_str == pa_str ->
            update_response(shokai, "person_a_response", response)

          user_str == pb_str ->
            update_response(shokai, "person_b_response", response)

          true ->
            {:error, :unauthorized}
        end
    end
  end

  def list_pending(user_id) do
    user_oid = to_oid(user_id)
    now = DateTime.utc_now()

    shokais =
      Repo.find(
        @shokais_collection,
        %{
          "status" => "pending",
          "expires_at" => %{"$gt" => now},
          "$or" => [
            %{person_a_id: user_oid},
            %{person_b_id: user_oid}
          ]
        },
        sort: %{inserted_at: -1}
      )
      |> Enum.to_list()

    {:ok, shokais}
  end

  def list_sent(matchmaker_id) do
    matchmaker_oid = to_oid(matchmaker_id)

    shokais =
      Repo.find(
        @shokais_collection,
        %{
          matchmaker_id: matchmaker_oid
        },
        sort: %{inserted_at: -1}
      )
      |> Enum.to_list()

    {:ok, shokais}
  end

  def get_shokai(shokai_id, user_id) do
    shokai_oid = to_oid(shokai_id)
    user_oid = to_oid(user_id)
    user_str = to_string(user_oid)

    case Repo.find_one(@shokais_collection, %{_id: shokai_oid}) do
      nil ->
        {:error, :not_found}

      shokai ->
        pa_str = to_string(shokai["person_a_id"])
        pb_str = to_string(shokai["person_b_id"])
        mm_str = to_string(shokai["matchmaker_id"])

        if user_str in [pa_str, pb_str, mm_str] do
          {:ok, shokai}
        else
          {:error, :unauthorized}
        end
    end
  end

  def get_suggestions(matchmaker_id) do
    case Koikoi.Matching.CardDealer.deal_cards(matchmaker_id) do
      {:ok, pairs} ->
        suggestions =
          Enum.map(pairs, fn pair ->
            %{
              person_a: pair.person_a,
              person_b: pair.person_b,
              shared_tags: pair.shared_tags,
              priority_score: pair.priority_score
            }
          end)

        {:ok, suggestions}

      error ->
        error
    end
  end

  def expire_stale do
    now = DateTime.utc_now()

    Repo.update_many(
      @shokais_collection,
      %{
        status: "pending",
        expires_at: %{"$lte" => now}
      },
      %{"$set" => %{status: "expired", updated_at: now}}
    )
  end

  # --- Private ---

  defp update_response(shokai, field, response) do
    now = DateTime.utc_now()
    shokai_oid = shokai["_id"]

    Repo.update_one(
      @shokais_collection,
      %{_id: shokai_oid},
      %{"$set" => %{field => response, "updated_at" => now}}
    )

    updated = Repo.find_one(@shokais_collection, %{_id: shokai_oid})

    a_resp = updated["person_a_response"]
    b_resp = updated["person_b_response"]

    cond do
      response == "declined" ->
        Repo.update_one(
          @shokais_collection,
          %{_id: shokai_oid},
          %{"$set" => %{status: "declined", updated_at: now}}
        )

        updated = Repo.find_one(@shokais_collection, %{_id: shokai_oid})
        {:ok, updated}

      a_resp == "accepted" and b_resp == "accepted" ->
        # Both accepted! Create conversation directly (they may not be friends yet)
        pa_oid = updated["person_a_id"]
        pb_oid = updated["person_b_id"]

        existing =
          Repo.find_one("conversations", %{
            type: %{"$in" => ["dm", "shokai"]},
            participants: %{"$all" => [pa_oid, pb_oid], "$size" => 2}
          })

        conversation =
          case existing do
            nil ->
              doc = %{
                type: "shokai",
                match_id: nil,
                name: nil,
                admin_ids: nil,
                participants:
                  Enum.sort([pa_oid, pb_oid], fn a, b -> to_string(a) < to_string(b) end),
                status: "active",
                last_message_at: nil,
                expires_at: nil,
                inserted_at: now,
                updated_at: now
              }

              {:ok, result} = Repo.insert_one("conversations", doc)
              Repo.find_one("conversations", %{_id: result.inserted_id})

            conv ->
              conv
          end

        conv_id = conversation["_id"]

        Repo.update_one(
          @shokais_collection,
          %{_id: shokai_oid},
          %{
            "$set" => %{
              status: "accepted",
              result_conversation_id: conv_id,
              updated_at: now
            }
          }
        )

        # Insert intro message
        matchmaker_name = get_nickname(to_string(updated["matchmaker_id"]))
        intro_content = "#{matchmaker_name || "仲人"}さんの紹介で繋がりました！"
        insert_system_message_in_conv(conv_id, intro_content)

        updated = Repo.find_one(@shokais_collection, %{_id: shokai_oid})
        {:ok, updated}

      true ->
        {:ok, updated}
    end
  end

  defp validate_friends_with_both(matchmaker_id, person_a_id, person_b_id) do
    if Social.are_friends?(matchmaker_id, person_a_id) and
         Social.are_friends?(matchmaker_id, person_b_id) do
      :ok
    else
      {:error, :not_friends_with_both}
    end
  end

  defp validate_no_active_shokai(person_a_id, person_b_id) do
    pa_oid = to_oid(person_a_id)
    pb_oid = to_oid(person_b_id)
    {a, b} = canonical_pair(pa_oid, pb_oid)

    existing =
      Repo.find_one(@shokais_collection, %{
        person_a_id: a,
        person_b_id: b,
        status: "pending"
      })

    if existing, do: {:error, :active_shokai_exists}, else: :ok
  end

  defp canonical_pair(oid_a, oid_b) do
    if to_string(oid_a) < to_string(oid_b), do: {oid_a, oid_b}, else: {oid_b, oid_a}
  end

  defp compute_shared_tags(person_a_id, person_b_id) do
    with {:ok, profile_a} <- Profiles.get_profile(person_a_id),
         {:ok, profile_b} <- Profiles.get_profile(person_b_id) do
      tags_a = profile_a["tags"] || []
      tags_b = profile_b["tags"] || []

      set_a = MapSet.new(tags_a, fn t -> t["value"] || t[:value] end)
      set_b = MapSet.new(tags_b, fn t -> t["value"] || t[:value] end)

      MapSet.intersection(set_a, set_b) |> Enum.to_list()
    else
      _ -> []
    end
  end

  defp get_nickname(user_id) do
    case Profiles.get_profile(user_id) do
      {:ok, profile} -> profile["nickname"]
      _ -> nil
    end
  end

  defp notify_shokai_created(shokai, matchmaker_id) do
    matchmaker_name = get_nickname(matchmaker_id) || "仲人"

    [to_string(shokai["person_a_id"]), to_string(shokai["person_b_id"])]
    |> Enum.each(fn recipient_id ->
      Koikoi.Notifications.create_notification(
        recipient_id,
        "shokai_received",
        "紹介が届きました",
        "#{matchmaker_name}さんからの紹介があります",
        %{
          "shokai_id" => to_string(shokai["_id"]),
          "matchmaker_id" => to_string(shokai["matchmaker_id"])
        }
      )
    end)
  end

  defp insert_system_message_in_conv(conv_oid, content) do
    now = DateTime.utc_now()
    conv_id = if is_binary(conv_oid), do: to_oid(conv_oid), else: conv_oid

    message = %{
      conversation_id: conv_id,
      sender_id: nil,
      content: content,
      message_type: "system",
      read_at: nil,
      inserted_at: now
    }

    Repo.insert_one("messages", message)

    Repo.update_one(
      "conversations",
      %{_id: conv_id},
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
