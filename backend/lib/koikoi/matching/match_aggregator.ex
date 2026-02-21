defmodule Koikoi.Matching.MatchAggregator do
  @moduledoc "Creates matches when pairs cross the threshold and manages introductions."

  alias Koikoi.{Repo, Profiles, Notifications, Chat}
  alias Koikoi.Matching.CompatibilityScorer

  @matches_collection "matches"
  @sessions_collection "matchmaking_sessions"
  @introduction_expiry_hours 72

  @doc """
  Check if a pair should be matched based on current ratings.
  Called after each new rating is submitted.
  """
  def check_and_create_match(person_a_id, person_b_id) do
    {a_id, b_id} = CompatibilityScorer.canonical_pair(person_a_id, person_b_id)

    if existing_active_match?(a_id, b_id) do
      {:ok, :already_matched}
    else
      score_data = CompatibilityScorer.calculate_score(a_id, b_id)

      cond do
        meets_normal_threshold?(score_data) ->
          create_match(a_id, b_id, score_data, "normal")

        meets_cold_start_threshold?(score_data) ->
          create_match(a_id, b_id, score_data, "cold_start")

        true ->
          {:ok, :below_threshold}
      end
    end
  end

  @doc "Check if an active match already exists for this pair."
  def existing_active_match?(person_a_id, person_b_id) do
    {a_id, b_id} = CompatibilityScorer.canonical_pair(person_a_id, person_b_id)
    a_oid = to_oid(a_id)
    b_oid = to_oid(b_id)

    match =
      Repo.find_one(@matches_collection, %{
        person_a_id: a_oid,
        person_b_id: b_oid,
        status: %{"$in" => ["pending_intro", "introduced", "chatting"]}
      })

    match != nil
  end

  # --- Threshold Checks ---

  defp meets_normal_threshold?(data) do
    data.human_ratings >= 3 and data.score >= 0.70 and data.strong_ratings >= 2
  end

  defp meets_cold_start_threshold?(data) do
    data.human_ratings >= 2 and data.ai_ratings >= 1 and
      data.score >= 0.75 and data.strong_ratings >= 2
  end

  # --- Match Creation ---

  defp create_match(a_id, b_id, score_data, match_type) do
    a_oid = to_oid(a_id)
    b_oid = to_oid(b_id)
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, @introduction_expiry_hours * 3600, :second)

    signal_summary = build_signal_summary(a_id, b_id, a_oid, b_oid)

    document = %{
      person_a_id: a_oid,
      person_b_id: b_oid,
      status: "pending_intro",
      compatibility_score: score_data.score,
      total_ratings: score_data.total_ratings,
      match_type: match_type,
      signal_summary: signal_summary,
      person_a_response: nil,
      person_b_response: nil,
      conversation_id: nil,
      expires_at: expires_at,
      inserted_at: now,
      updated_at: now
    }

    case Repo.insert_one(@matches_collection, document) do
      {:ok, result} ->
        match = Repo.find_one(@matches_collection, %{_id: result.inserted_id})
        match_id = to_string(result.inserted_id)

        # Notify both users about the new match
        Notifications.create_notification(
          a_id,
          "new_match",
          "新しいマッチ",
          "あなたに新しいマッチが見つかりました！",
          %{"match_id" => match_id}
        )

        Notifications.create_notification(
          b_id,
          "new_match",
          "新しいマッチ",
          "あなたに新しいマッチが見つかりました！",
          %{"match_id" => match_id}
        )

        {:ok, {:match_created, match}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_signal_summary(a_id, b_id, a_oid, b_oid) do
    shared_tags = compute_shared_tags(a_id, b_id)
    top_notes = get_top_matchmaker_notes(a_oid, b_oid)

    strong_count =
      Repo.find(@sessions_collection, %{
        person_a_id: a_oid,
        person_b_id: b_oid,
        skipped: false
      })
      |> Enum.count(fn s -> s["rating"] >= 4 end)

    %{
      shared_tags: shared_tags,
      top_matchmaker_notes: top_notes,
      strong_rating_count: strong_count
    }
  end

  defp compute_shared_tags(a_id, b_id) do
    with {:ok, profile_a} <- Profiles.get_profile(a_id),
         {:ok, profile_b} <- Profiles.get_profile(b_id) do
      tags_a = profile_a["tags"] || []
      tags_b = profile_b["tags"] || []

      set_a = MapSet.new(tags_a, fn t -> t["value"] end)
      set_b = MapSet.new(tags_b, fn t -> t["value"] end)

      MapSet.intersection(set_a, set_b) |> Enum.to_list()
    else
      _ -> []
    end
  end

  defp get_top_matchmaker_notes(a_oid, b_oid) do
    Repo.find(
      @sessions_collection,
      %{
        person_a_id: a_oid,
        person_b_id: b_oid,
        skipped: false
      },
      sort: %{rating: -1},
      limit: 3
    )
    |> Enum.to_list()
    |> Enum.map(fn s ->
      signals = s["signals"] || %{}
      signals["matchmaker_note"]
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Respond to an introduction (accept or decline).
  """
  def respond_to_match(match_id, user_id, response) when response in ["accepted", "declined"] do
    match_oid = to_oid(match_id)
    user_oid = to_oid(user_id)

    case Repo.find_one(@matches_collection, %{_id: match_oid}) do
      nil ->
        {:error, :not_found}

      match ->
        user_oid_str = to_string(user_oid)
        person_a_str = to_string(match["person_a_id"])
        person_b_str = to_string(match["person_b_id"])

        cond do
          match["status"] != "pending_intro" ->
            {:error, "match_not_pending"}

          user_oid_str == person_a_str ->
            update_response(match, "person_a_response", response)

          user_oid_str == person_b_str ->
            update_response(match, "person_b_response", response)

          true ->
            {:error, :unauthorized}
        end
    end
  end

  defp update_response(match, field, response) do
    now = DateTime.utc_now()

    Repo.update_one(
      @matches_collection,
      %{_id: match["_id"]},
      %{"$set" => %{field => response, "updated_at" => now}}
    )

    updated = Repo.find_one(@matches_collection, %{_id: match["_id"]})

    # Check if both have responded
    a_resp = if field == "person_a_response", do: response, else: match["person_a_response"]
    b_resp = if field == "person_b_response", do: response, else: match["person_b_response"]

    match_id = to_string(match["_id"])
    person_a_id = to_string(match["person_a_id"])
    person_b_id = to_string(match["person_b_id"])

    # Determine the "other" user for notifications
    {_responder_id, other_id} =
      if field == "person_a_response" do
        {person_a_id, person_b_id}
      else
        {person_b_id, person_a_id}
      end

    cond do
      response == "declined" ->
        Repo.update_one(
          @matches_collection,
          %{_id: match["_id"]},
          %{"$set" => %{status: "declined", updated_at: now}}
        )

        {:ok, Repo.find_one(@matches_collection, %{_id: match["_id"]})}

      a_resp == "accepted" and b_resp == "accepted" ->
        # Create conversation for the matched pair
        {:ok, conversation} = Chat.create_conversation(match_id, person_a_id, person_b_id)
        conversation_id = to_string(conversation["_id"])

        Repo.update_one(
          @matches_collection,
          %{_id: match["_id"]},
          %{
            "$set" => %{
              status: "introduced",
              conversation_id: conversation["_id"],
              updated_at: now
            }
          }
        )

        # Notify the other user that the match was accepted
        Notifications.create_notification(
          other_id,
          "match_accepted",
          "マッチが成立しました",
          "お相手があなたとのマッチを承諾しました。チャットを始めましょう！",
          %{"match_id" => match_id, "conversation_id" => conversation_id}
        )

        {:ok, Repo.find_one(@matches_collection, %{_id: match["_id"]})}

      response == "accepted" ->
        # One side accepted, notify the other user
        Notifications.create_notification(
          other_id,
          "match_accepted",
          "紹介への返答",
          "お相手が紹介を承諾しました。あなたの返答をお待ちしています。",
          %{"match_id" => match_id}
        )

        {:ok, updated}

      true ->
        {:ok, updated}
    end
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
