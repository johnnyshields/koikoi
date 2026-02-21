defmodule Koikoi.Matching.CompatibilityScorer do
  @moduledoc "Calculates weighted compatibility scores from matchmaker ratings."

  alias Koikoi.{Repo, Social}

  @sessions_collection "matchmaking_sessions"

  @doc """
  Calculate compatibility score for a pair.
  Returns a map with score, rating counts, and weight details.
  """
  def calculate_score(person_a_id, person_b_id) do
    {a_id, b_id} = canonical_pair(person_a_id, person_b_id)
    a_oid = to_oid(a_id)
    b_oid = to_oid(b_id)

    sessions = get_pair_sessions(a_oid, b_oid)
    rated = Enum.filter(sessions, fn s -> !s["skipped"] end)

    if Enum.empty?(rated) do
      %{
        score: 0.0,
        total_ratings: 0,
        human_ratings: 0,
        ai_ratings: 0,
        strong_ratings: 0,
        weighted_sum: 0.0,
        weight_total: 0.0
      }
    else
      {weighted_sum, weight_total} =
        Enum.reduce(rated, {0.0, 0.0}, fn session, {ws, wt} ->
          weight = calculate_weight(session, a_id, b_id)
          normalized = (session["rating"] - 1) / 4.0
          {ws + normalized * weight, wt + weight}
        end)

      score = if weight_total > 0, do: weighted_sum / weight_total, else: 0.0

      human_ratings = Enum.count(rated, fn s -> !s["is_ai"] end)
      ai_ratings = Enum.count(rated, fn s -> s["is_ai"] end)
      strong_ratings = Enum.count(rated, fn s -> s["rating"] >= 4 end)

      %{
        score: Float.round(score, 4),
        total_ratings: length(rated),
        human_ratings: human_ratings,
        ai_ratings: ai_ratings,
        strong_ratings: strong_ratings,
        weighted_sum: weighted_sum,
        weight_total: weight_total
      }
    end
  end

  # --- Weight Calculation ---

  defp calculate_weight(session, person_a_id, person_b_id) do
    confidence_mult = confidence_multiplier(session["confidence"])
    tier_mult = tier_multiplier(session, person_a_id, person_b_id)
    recency_mult = recency_multiplier(session["inserted_at"])
    ai_mult = if session["is_ai"], do: 0.3, else: 1.0

    confidence_mult * tier_mult * recency_mult * ai_mult
  end

  defp confidence_multiplier("low"), do: 0.5
  defp confidence_multiplier("high"), do: 1.5
  defp confidence_multiplier(_), do: 1.0

  defp tier_multiplier(session, person_a_id, person_b_id) do
    matchmaker_id = to_string(session["matchmaker_id"])
    tier_a = Social.get_trust_tier(matchmaker_id, to_string(person_a_id))
    tier_b = Social.get_trust_tier(matchmaker_id, to_string(person_b_id))

    cond do
      tier_a == "inner_circle" and tier_b == "inner_circle" -> 2.0
      tier_a == "inner_circle" or tier_b == "inner_circle" -> 1.5
      tier_a == "friends" and tier_b == "friends" -> 1.0
      true -> 0.7
    end
  end

  defp recency_multiplier(nil), do: 0.6

  defp recency_multiplier(inserted_at) do
    now = DateTime.utc_now()
    days = DateTime.diff(now, inserted_at, :second) / 86_400.0

    cond do
      days <= 7 -> 1.0
      days <= 30 -> 0.9
      days <= 90 -> 0.8
      true -> 0.6
    end
  end

  # --- Queries ---

  defp get_pair_sessions(a_oid, b_oid) do
    Repo.find(@sessions_collection, %{
      person_a_id: a_oid,
      person_b_id: b_oid
    })
    |> Enum.to_list()
  end

  # --- Helpers ---

  def canonical_pair(id_a, id_b) do
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
