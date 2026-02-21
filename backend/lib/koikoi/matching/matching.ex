defmodule Koikoi.Matching do
  @moduledoc """
  The Matching context manages matchmaking sessions, compatibility scoring,
  match creation, and introduction flow.
  """

  alias Koikoi.Matching.{CardDealer, CompatibilityScorer, MatchAggregator}
  alias Koikoi.Repo

  @sessions_collection "matchmaking_sessions"
  @matches_collection "matches"

  # --- Card Dealing ---

  def deal_cards(matchmaker_id), do: CardDealer.deal_cards(matchmaker_id)

  # --- Rating Submission ---

  def submit_rating(matchmaker_id, person_a_id, person_b_id, attrs) do
    {a_id, b_id} = canonical_pair(person_a_id, person_b_id)

    rating = attrs["rating"]

    cond do
      !is_integer(rating) or rating < 1 or rating > 5 ->
        {:error, "invalid_rating"}

      true ->
        session = %{
          matchmaker_id: to_oid(matchmaker_id),
          person_a_id: to_oid(a_id),
          person_b_id: to_oid(b_id),
          rating: rating,
          confidence: attrs["confidence"] || "medium",
          signals: %{
            shared_tags: attrs["shared_tags"] || [],
            matchmaker_note: attrs["note"]
          },
          is_ai: attrs["is_ai"] || false,
          skipped: false,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }

        case Repo.insert_one(@sessions_collection, session) do
          {:ok, result} ->
            session_doc = Repo.find_one(@sessions_collection, %{_id: result.inserted_id})
            match_result = MatchAggregator.check_and_create_match(a_id, b_id)
            {:ok, %{session: session_doc, match_result: match_result}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # --- Skip Pair ---

  def skip_pair(matchmaker_id, person_a_id, person_b_id) do
    {a_id, b_id} = canonical_pair(person_a_id, person_b_id)

    session = %{
      matchmaker_id: to_oid(matchmaker_id),
      person_a_id: to_oid(a_id),
      person_b_id: to_oid(b_id),
      rating: nil,
      confidence: nil,
      signals: %{},
      is_ai: false,
      skipped: true,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    case Repo.insert_one(@sessions_collection, session) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Introduction Flow ---

  def respond_to_match(match_id, user_id, response) when response in ["accepted", "declined"] do
    MatchAggregator.respond_to_match(match_id, user_id, response)
  end

  def respond_to_match(_match_id, _user_id, _response) do
    {:error, "invalid_response"}
  end

  # --- Match Queries ---

  def list_matches(user_id, opts \\ []) do
    user_oid = to_oid(user_id)
    status = Keyword.get(opts, :status)
    page = Keyword.get(opts, :page, 1)
    limit = Keyword.get(opts, :limit, 20)
    skip = (page - 1) * limit

    base_filter = %{
      "$or" => [
        %{person_a_id: user_oid},
        %{person_b_id: user_oid}
      ]
    }

    filter =
      if status && status != "" do
        Map.put(base_filter, "status", status)
      else
        base_filter
      end

    matches =
      Repo.find(@matches_collection, filter,
        sort: %{inserted_at: -1},
        skip: skip,
        limit: limit
      )
      |> Enum.to_list()

    {:ok, matches}
  end

  def get_match(match_id, user_id) do
    match_oid = to_oid(match_id)
    user_oid = to_oid(user_id)

    case Repo.find_one(@matches_collection, %{_id: match_oid}) do
      nil ->
        {:error, :not_found}

      match ->
        user_str = to_string(user_oid)
        a_str = to_string(match["person_a_id"])
        b_str = to_string(match["person_b_id"])

        if user_str == a_str or user_str == b_str do
          {:ok, match}
        else
          {:error, :unauthorized}
        end
    end
  end

  # --- Matchmaker Stats ---

  def get_matchmaker_stats(matchmaker_id) do
    matchmaker_oid = to_oid(matchmaker_id)

    total_ratings =
      Repo.count_documents(@sessions_collection, %{
        matchmaker_id: matchmaker_oid,
        skipped: false
      })

    total_skipped =
      Repo.count_documents(@sessions_collection, %{
        matchmaker_id: matchmaker_oid,
        skipped: true
      })

    # Get unique pairs rated by this matchmaker that resulted in matches
    rated_sessions =
      Repo.find(@sessions_collection, %{
        matchmaker_id: matchmaker_oid,
        skipped: false
      })
      |> Enum.to_list()

    # Count unique pairs that have active matches
    successful_matches =
      rated_sessions
      |> Enum.map(fn s -> {s["person_a_id"], s["person_b_id"]} end)
      |> Enum.uniq()
      |> Enum.count(fn {a_oid, b_oid} ->
        match =
          Repo.find_one(@matches_collection, %{
            person_a_id: a_oid,
            person_b_id: b_oid,
            status: %{"$in" => ["pending_intro", "introduced", "chatting"]}
          })

        match != nil
      end)

    # Average rating
    rating_average =
      if total_ratings > 0 do
        sum =
          rated_sessions
          |> Enum.map(fn s -> s["rating"] || 0 end)
          |> Enum.sum()

        Float.round(sum / total_ratings, 2)
      else
        0.0
      end

    {:ok,
     %{
       total_ratings: total_ratings,
       total_skipped: total_skipped,
       successful_matches: successful_matches,
       rating_average: rating_average
     }}
  end

  # --- Compatibility Score ---

  def get_pair_score(person_a_id, person_b_id) do
    CompatibilityScorer.calculate_score(person_a_id, person_b_id)
  end

  # --- Helpers ---

  defp canonical_pair(id_a, id_b) do
    a = to_string(id_a)
    b = to_string(id_b)
    if a < b, do: {a, b}, else: {b, a}
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
