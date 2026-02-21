defmodule Koikoi.Matching.CardDealer do
  @moduledoc "Selects and prioritizes pairs for matchmaker rating."

  alias Koikoi.{Repo, Social, Profiles}

  @sessions_collection "matchmaking_sessions"
  @matches_collection "matches"
  @batch_size 10

  @doc """
  Deal a batch of pair cards to a matchmaker.
  Returns {:ok, pairs} where each pair contains person summaries,
  shared tags, and a priority score.
  """
  def deal_cards(matchmaker_id) do
    with {:ok, user_ids} <- Social.get_matchable_users(matchmaker_id) do
      if length(user_ids) < 2 do
        {:ok, []}
      else
        profiles = load_profiles(user_ids)

        pairs =
          profiles
          |> generate_pairs()
          |> filter_rated_and_matched(matchmaker_id)
          |> score_pairs(matchmaker_id)
          |> Enum.sort_by(& &1.priority_score, :desc)
          |> Enum.take(@batch_size)

        {:ok, pairs}
      end
    end
  end

  # --- Profile Loading ---

  defp load_profiles(user_ids) do
    user_ids
    |> Enum.reduce([], fn user_id, acc ->
      case Profiles.get_profile(user_id) do
        {:ok, profile} ->
          if Social.is_matchmaking_active?(user_id) do
            [{user_id, profile} | acc]
          else
            acc
          end

        {:error, _} ->
          acc
      end
    end)
  end

  # --- Pair Generation ---

  defp generate_pairs(profiles) do
    for {id_a, profile_a} <- profiles,
        {id_b, profile_b} <- profiles,
        id_a < id_b,
        cross_preference?(profile_a, profile_b) do
      shared = compute_shared_tags(profile_a, profile_b)

      %{
        person_a: build_person_summary(id_a, profile_a),
        person_b: build_person_summary(id_b, profile_b),
        shared_tags: shared,
        priority_score: 0.0
      }
    end
  end

  defp cross_preference?(profile_a, profile_b) do
    prefs_a = profile_a["preferences"] || %{}
    prefs_b = profile_b["preferences"] || %{}

    gender_a = get_gender(profile_a)
    gender_b = get_gender(profile_b)

    preferred_a = prefs_a["preferred_genders"] || prefs_a[:preferred_genders] || []
    preferred_b = prefs_b["preferred_genders"] || prefs_b[:preferred_genders] || []

    # If no preferences set, consider it open
    a_accepts_b = Enum.empty?(preferred_a) or gender_b in preferred_a
    b_accepts_a = Enum.empty?(preferred_b) or gender_a in preferred_b

    a_accepts_b and b_accepts_a
  end

  defp get_gender(profile) do
    user_id = to_string(profile["user_id"])

    case Koikoi.Accounts.get_user(user_id) do
      nil -> nil
      user -> user["gender"]
    end
  end

  defp compute_shared_tags(profile_a, profile_b) do
    tags_a = profile_a["tags"] || profile_a[:tags] || []
    tags_b = profile_b["tags"] || profile_b[:tags] || []

    set_a =
      MapSet.new(tags_a, fn t -> {t["category"] || t[:category], t["value"] || t[:value]} end)

    set_b =
      MapSet.new(tags_b, fn t -> {t["category"] || t[:category], t["value"] || t[:value]} end)

    MapSet.intersection(set_a, set_b)
    |> Enum.map(fn {category, value} -> %{category: category, value: value} end)
  end

  defp build_person_summary(user_id, profile) do
    photos = profile["photos"] || profile[:photos] || []
    primary_photo = Enum.find(photos, fn p -> p["is_primary"] || p[:is_primary] end)
    age = calculate_age(user_id)

    %{
      user_id: user_id,
      nickname: profile["nickname"] || profile[:nickname],
      primary_photo: primary_photo,
      age: age,
      prefecture:
        get_in(profile, ["location", "prefecture"]) ||
          get_in(profile, [:location, :prefecture]),
      tags: profile["tags"] || profile[:tags] || [],
      profile_completeness:
        profile["profile_completeness"] || profile[:profile_completeness] || 0.0
    }
  end

  defp calculate_age(user_id) do
    case Koikoi.Accounts.get_user(to_string(user_id)) do
      nil ->
        nil

      user ->
        case user["date_of_birth"] do
          %Date{} = dob ->
            today = Date.utc_today()
            age = today.year - dob.year

            if Date.compare(Date.new!(today.year, dob.month, dob.day), today) == :gt do
              age - 1
            else
              age
            end

          _ ->
            nil
        end
    end
  end

  # --- Filtering ---

  defp filter_rated_and_matched(pairs, matchmaker_id) do
    matchmaker_oid = to_oid(matchmaker_id)

    Enum.filter(pairs, fn pair ->
      a_id = pair.person_a.user_id
      b_id = pair.person_b.user_id
      a_oid = to_oid(a_id)
      b_oid = to_oid(b_id)

      # Check if matchmaker already rated/skipped this pair
      already_rated =
        Repo.find_one(@sessions_collection, %{
          matchmaker_id: matchmaker_oid,
          person_a_id: a_oid,
          person_b_id: b_oid
        })

      # Check if pair already has an active match
      active_match =
        Repo.find_one(@matches_collection, %{
          person_a_id: a_oid,
          person_b_id: b_oid,
          status: %{"$in" => ["pending_intro", "introduced", "chatting"]}
        })

      is_nil(already_rated) and is_nil(active_match)
    end)
  end

  # --- Priority Scoring ---

  defp score_pairs(pairs, matchmaker_id) do
    Enum.map(pairs, fn pair ->
      tag_overlap = tag_overlap_score(pair)
      completeness = completeness_score(pair)
      cold_pair = cold_pair_bonus(pair)
      familiarity = matchmaker_familiarity_score(pair, matchmaker_id)
      freshness = freshness_penalty(pair)

      score =
        tag_overlap * 0.30 +
          completeness * 0.20 +
          cold_pair * 0.20 +
          familiarity * 0.20 +
          freshness

      %{pair | priority_score: Float.round(score, 4)}
    end)
  end

  defp tag_overlap_score(pair) do
    tags_a =
      MapSet.new(pair.person_a.tags, fn t ->
        {t["category"] || t[:category], t["value"] || t[:value]}
      end)

    tags_b =
      MapSet.new(pair.person_b.tags, fn t ->
        {t["category"] || t[:category], t["value"] || t[:value]}
      end)

    intersection = MapSet.intersection(tags_a, tags_b) |> MapSet.size()
    union = MapSet.union(tags_a, tags_b) |> MapSet.size()

    if union == 0, do: 0.0, else: intersection / union
  end

  defp completeness_score(pair) do
    a = pair.person_a.profile_completeness || 0.0
    b = pair.person_b.profile_completeness || 0.0
    (a + b) / 2.0
  end

  defp cold_pair_bonus(pair) do
    a_oid = to_oid(pair.person_a.user_id)
    b_oid = to_oid(pair.person_b.user_id)

    total_ratings =
      Repo.count_documents(@sessions_collection, %{
        person_a_id: a_oid,
        person_b_id: b_oid,
        skipped: false
      })

    1.0 - min(total_ratings, 10) / 10.0
  end

  defp matchmaker_familiarity_score(pair, matchmaker_id) do
    tier_a = Social.get_trust_tier(matchmaker_id, pair.person_a.user_id)
    tier_b = Social.get_trust_tier(matchmaker_id, pair.person_b.user_id)

    cond do
      tier_a == "inner_circle" and tier_b == "inner_circle" -> 1.0
      tier_a == "inner_circle" or tier_b == "inner_circle" -> 0.75
      tier_a == "friends" and tier_b == "friends" -> 0.5
      true -> 0.25
    end
  end

  defp freshness_penalty(pair) do
    a_oid = to_oid(pair.person_a.user_id)
    b_oid = to_oid(pair.person_b.user_id)

    total_sessions =
      Repo.count_documents(@sessions_collection, %{
        person_a_id: a_oid,
        person_b_id: b_oid
      })

    active_match =
      Repo.find_one(@matches_collection, %{
        person_a_id: a_oid,
        person_b_id: b_oid,
        status: %{"$in" => ["pending_intro", "introduced", "chatting"]}
      })

    if total_sessions >= 10 and is_nil(active_match) do
      -0.10
    else
      0.0
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
