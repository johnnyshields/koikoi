defmodule Koikoi.AiMatchmaker.ColdStartWorker do
  @moduledoc """
  GenServer that periodically generates AI ratings for cold-start users.
  Cold-start users have matchmaking active but few ratings on their pairs.
  """

  use GenServer
  require Logger

  alias Koikoi.{Repo, Social, Profiles, Accounts, Matching}
  alias Koikoi.AiMatchmaker.{ProfileAnalyzer, Persona}

  @check_interval :timer.minutes(10)
  @sessions_collection "matchmaking_sessions"
  @connections_collection "connections"
  @cold_start_rating_threshold 5
  @pair_rating_threshold 3
  @max_ai_ratings_per_user 5

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Manually trigger cold-start analysis for a specific user."
  def trigger_for_user(user_id) do
    GenServer.cast(__MODULE__, {:trigger_user, user_id})
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_cold_start, state) do
    run_cold_start_scan()
    schedule_check()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:trigger_user, user_id}, state) do
    generate_ai_ratings_for_user(user_id)
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_cold_start, @check_interval)
  end

  defp run_cold_start_scan do
    candidates = find_cold_start_candidates()

    Enum.each(candidates, fn user_id ->
      generate_ai_ratings_for_user(user_id)
    end)
  end

  @doc false
  def find_cold_start_candidates do
    # Find users who have matchmaking active (2+ matchmakers)
    # but have few total pair ratings
    active_connections =
      Repo.find(@connections_collection, %{
        type: "matchmaker",
        status: "accepted"
      })
      |> Enum.to_list()

    # Group by subject_id to count matchmakers per user
    subject_counts =
      Enum.group_by(active_connections, fn c -> to_string(c["subject_id"]) end)
      |> Enum.filter(fn {_id, conns} -> length(conns) >= 2 end)
      |> Enum.map(fn {id, _conns} -> id end)

    # Filter to users with few total ratings on their pairs
    Enum.filter(subject_counts, fn user_id ->
      user_oid = to_oid(user_id)

      total_ratings =
        Repo.count_documents(@sessions_collection, %{
          "$or" => [
            %{person_a_id: user_oid},
            %{person_b_id: user_oid}
          ],
          skipped: false
        })

      total_ratings < @cold_start_rating_threshold
    end)
  end

  defp generate_ai_ratings_for_user(user_id) do
    # Get matchable pairs for this user
    pairs = find_matchable_pairs(user_id)

    # Filter to pairs with few ratings
    eligible_pairs =
      Enum.filter(pairs, fn {a_id, b_id} ->
        pair_rating_count(a_id, b_id) < @pair_rating_threshold
      end)

    # Limit AI ratings per run
    pairs_to_rate = Enum.take(eligible_pairs, @max_ai_ratings_per_user)

    Enum.each(pairs_to_rate, fn {a_id, b_id} ->
      generate_and_submit_rating(a_id, b_id)
    end)

    Logger.info("AI Cupid generated #{length(pairs_to_rate)} ratings for user #{user_id}")
  end

  defp find_matchable_pairs(user_id) do
    # Get all users that share matchmakers with this user
    matchmaker_conns =
      Repo.find(@connections_collection, %{
        type: "matchmaker",
        status: "accepted",
        subject_id: to_oid(user_id)
      })
      |> Enum.to_list()

    matchmaker_ids = Enum.map(matchmaker_conns, fn c -> to_string(c["matchmaker_id"]) end)

    # For each matchmaker, get their other subjects
    other_user_ids =
      Enum.flat_map(matchmaker_ids, fn mm_id ->
        case Social.get_matchable_users(mm_id) do
          {:ok, ids} -> ids
          _ -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.reject(fn id -> id == user_id end)

    # Generate canonical pairs
    Enum.map(other_user_ids, fn other_id ->
      canonical_pair(user_id, other_id)
    end)
    |> Enum.uniq()
  end

  defp pair_rating_count(a_id, b_id) do
    a_oid = to_oid(a_id)
    b_oid = to_oid(b_id)

    Repo.count_documents(@sessions_collection, %{
      person_a_id: a_oid,
      person_b_id: b_oid,
      skipped: false
    })
  end

  defp generate_and_submit_rating(a_id, b_id) do
    with {:ok, profile_a} <- Profiles.get_profile(a_id),
         {:ok, profile_b} <- Profiles.get_profile(b_id),
         user_a when not is_nil(user_a) <- Accounts.get_user(a_id),
         user_b when not is_nil(user_b) <- Accounts.get_user(b_id) do
      analysis = ProfileAnalyzer.analyze(profile_a, profile_b, user_a, user_b)
      note = Persona.generate_note(analysis.reasons)

      attrs = %{
        "rating" => analysis.score,
        "confidence" => analysis.confidence,
        "note" => note,
        "is_ai" => true,
        "shared_tags" => extract_shared_tags(profile_a, profile_b)
      }

      case Matching.submit_rating(Persona.id(), a_id, b_id, attrs) do
        {:ok, _result} ->
          Logger.debug("AI Cupid rated pair #{a_id}/#{b_id}: #{analysis.score}")

        {:error, reason} ->
          Logger.warning("AI Cupid failed to rate pair #{a_id}/#{b_id}: #{inspect(reason)}")
      end
    else
      error ->
        Logger.warning("AI Cupid could not analyze pair #{a_id}/#{b_id}: #{inspect(error)}")
    end
  end

  defp extract_shared_tags(profile_a, profile_b) do
    tags_a = profile_a["tags"] || profile_a[:tags] || []
    tags_b = profile_b["tags"] || profile_b[:tags] || []

    set_a = MapSet.new(tags_a, fn t -> t["value"] || t[:value] end)
    set_b = MapSet.new(tags_b, fn t -> t["value"] || t[:value] end)

    MapSet.intersection(set_a, set_b) |> Enum.to_list()
  end

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
