defmodule Koikoi.AiMatchmaker.ProfileAnalyzer do
  @moduledoc "Analyzes profile compatibility using rule-based scoring."

  @doc """
  Analyze compatibility between two profiles.
  Returns %{
    score: integer (1-5 scale, like a human rating),
    confidence: "low" | "medium" | "high",
    reasons: [%{type: string, description_ja: string, description_en: string, weight: float}]
  }
  """
  def analyze(profile_a, profile_b, user_a, user_b) do
    scores = [
      tag_similarity(profile_a, profile_b),
      lifestyle_alignment(profile_a, profile_b),
      location_proximity(profile_a, profile_b),
      age_compatibility(user_a, user_b, profile_a, profile_b),
      relationship_goals(profile_a, profile_b),
      profile_quality(profile_a, profile_b)
    ]

    weighted_score =
      Enum.reduce(scores, 0.0, fn {score, weight, _reasons}, acc ->
        acc + score * weight
      end)

    reasons =
      scores
      |> Enum.flat_map(fn {_s, _w, reasons} -> reasons end)
      |> Enum.filter(fn r -> r.weight > 0.3 end)
      |> Enum.sort_by(& &1.weight, :desc)
      |> Enum.take(3)

    # Convert 0-1 score to 1-5 rating
    rating = round(weighted_score * 4 + 1)
    rating = max(1, min(5, rating))

    confidence =
      cond do
        length(reasons) >= 3 -> "high"
        length(reasons) >= 1 -> "medium"
        true -> "low"
      end

    %{score: rating, confidence: confidence, reasons: reasons}
  end

  # --- Tag Similarity (25%) ---

  defp tag_similarity(profile_a, profile_b) do
    tags_a = extract_tag_values(profile_a)
    tags_b = extract_tag_values(profile_b)

    set_a = MapSet.new(tags_a)
    set_b = MapSet.new(tags_b)

    intersection_size = MapSet.intersection(set_a, set_b) |> MapSet.size()
    union_size = MapSet.union(set_a, set_b) |> MapSet.size()

    base_score = if union_size == 0, do: 0.0, else: intersection_size / union_size

    # Bonus for 5+ shared tags
    score = if intersection_size >= 5, do: min(base_score + 0.15, 1.0), else: base_score

    reasons =
      if intersection_size > 0 do
        [
          %{
            type: "shared_interests",
            description_ja: "共通の趣味が#{intersection_size}個あります",
            description_en: "#{intersection_size} shared interests",
            weight: min(intersection_size * 0.15, 1.0)
          }
        ]
      else
        []
      end

    {score, 0.25, reasons}
  end

  # --- Lifestyle Alignment (20%) ---

  defp lifestyle_alignment(profile_a, profile_b) do
    lifestyle_a = get_lifestyle(profile_a)
    lifestyle_b = get_lifestyle(profile_b)

    drinking_score = compare_lifestyle_value(lifestyle_a["drinking"], lifestyle_b["drinking"])
    smoking_score = compare_lifestyle_value(lifestyle_a["smoking"], lifestyle_b["smoking"])

    score = (drinking_score + smoking_score) / 2.0

    reasons =
      if score >= 0.7 do
        [
          %{
            type: "lifestyle",
            description_ja: "ライフスタイルが似ています",
            description_en: "Similar lifestyle",
            weight: score
          }
        ]
      else
        []
      end

    {score, 0.20, reasons}
  end

  # --- Location Proximity (15%) ---

  defp location_proximity(profile_a, profile_b) do
    prefecture_a = get_prefecture(profile_a)
    prefecture_b = get_prefecture(profile_b)
    city_a = get_city(profile_a)
    city_b = get_city(profile_b)

    {score, reason_text_ja, reason_text_en} =
      cond do
        is_nil(prefecture_a) or is_nil(prefecture_b) ->
          {0.1, nil, nil}

        prefecture_a == prefecture_b and city_a == city_b and not is_nil(city_a) ->
          {1.0, "お近くにお住まいです", "Live nearby"}

        prefecture_a == prefecture_b ->
          {0.7, "お近くにお住まいです", "Live nearby"}

        adjacent_prefectures?(prefecture_a, prefecture_b) ->
          {0.3, "比較的お近くにお住まいです", "Live relatively nearby"}

        true ->
          {0.1, nil, nil}
      end

    reasons =
      if reason_text_ja do
        [
          %{
            type: "location",
            description_ja: reason_text_ja,
            description_en: reason_text_en,
            weight: score
          }
        ]
      else
        []
      end

    {score, 0.15, reasons}
  end

  # --- Age Compatibility (15%) ---

  defp age_compatibility(user_a, user_b, profile_a, profile_b) do
    age_a = calculate_age(user_a)
    age_b = calculate_age(user_b)

    if is_nil(age_a) or is_nil(age_b) do
      {0.5, 0.15, []}
    else
      prefs_a = get_preferences(profile_a)
      prefs_b = get_preferences(profile_b)

      score_a = age_in_range_score(age_b, prefs_a)
      score_b = age_in_range_score(age_a, prefs_b)

      score = (score_a + score_b) / 2.0

      reasons =
        if score >= 0.7 do
          [
            %{
              type: "age",
              description_ja: "年齢の相性が良いです",
              description_en: "Good age match",
              weight: score
            }
          ]
        else
          []
        end

      {score, 0.15, reasons}
    end
  end

  # --- Relationship Goals (15%) ---

  defp relationship_goals(profile_a, profile_b) do
    rel_a = get_relationship(profile_a)
    rel_b = get_relationship(profile_b)

    marriage_score = compare_intent(rel_a["marriage_intent"], rel_b["marriage_intent"])
    children_score = compare_intent(rel_a["wants_children"], rel_b["wants_children"])

    score = marriage_score * 0.6 + children_score * 0.4

    reasons =
      if score >= 0.6 do
        [
          %{
            type: "goals",
            description_ja: "結婚観が合っています",
            description_en: "Compatible relationship goals",
            weight: score
          }
        ]
      else
        []
      end

    {score, 0.15, reasons}
  end

  # --- Profile Quality (10%) ---

  defp profile_quality(profile_a, profile_b) do
    completeness_a = get_completeness(profile_a)
    completeness_b = get_completeness(profile_b)

    score = (completeness_a + completeness_b) / 2.0

    reasons =
      if score < 0.4 do
        [
          %{
            type: "quality",
            description_ja: "プロフィールをもっと充実させましょう",
            description_en: "Consider completing your profiles",
            weight: 0.2
          }
        ]
      else
        []
      end

    {score, 0.10, reasons}
  end

  # --- Private Helpers ---

  defp extract_tag_values(profile) do
    tags = profile["tags"] || profile[:tags] || []
    Enum.map(tags, fn t -> t["value"] || t[:value] end) |> Enum.reject(&is_nil/1)
  end

  defp get_lifestyle(profile) do
    profile["lifestyle"] || profile[:lifestyle] || %{}
  end

  defp get_prefecture(profile) do
    loc = profile["location"] || profile[:location] || %{}
    loc["prefecture"] || loc[:prefecture]
  end

  defp get_city(profile) do
    loc = profile["location"] || profile[:location] || %{}
    loc["city"] || loc[:city]
  end

  defp get_preferences(profile) do
    profile["preferences"] || profile[:preferences] || %{}
  end

  defp get_relationship(profile) do
    profile["relationship"] || profile[:relationship] || %{}
  end

  defp get_completeness(profile) do
    profile["profile_completeness"] || profile[:profile_completeness] || 0.0
  end

  defp compare_lifestyle_value(nil, _), do: 0.5
  defp compare_lifestyle_value(_, nil), do: 0.5

  defp compare_lifestyle_value(a, b) when a == b, do: 1.0

  defp compare_lifestyle_value(a, b) do
    scale = %{
      "never" => 0,
      "rarely" => 1,
      "sometimes" => 2,
      "often" => 3,
      "daily" => 4,
      "non_smoker" => 0,
      "quit" => 1,
      "occasional" => 2,
      "smoker" => 3,
      "non_drinker" => 0,
      "social" => 1,
      "regular" => 2
    }

    val_a = Map.get(scale, a)
    val_b = Map.get(scale, b)

    if is_nil(val_a) or is_nil(val_b) do
      0.5
    else
      diff = abs(val_a - val_b)

      cond do
        diff == 0 -> 1.0
        diff == 1 -> 0.5
        true -> 0.0
      end
    end
  end

  defp calculate_age(nil), do: nil

  defp calculate_age(user) do
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

  defp age_in_range_score(age, preferences) do
    age_range = preferences["age_range"] || preferences[:age_range]

    if is_nil(age_range) do
      0.7
    else
      min_age = age_range["min"] || age_range[:min]
      max_age = age_range["max"] || age_range[:max]

      cond do
        is_nil(min_age) or is_nil(max_age) ->
          0.7

        age >= min_age and age <= max_age ->
          1.0

        age >= min_age - 3 and age <= max_age + 3 ->
          0.5

        true ->
          0.2
      end
    end
  end

  defp compare_intent(nil, _), do: 0.5
  defp compare_intent(_, nil), do: 0.5
  defp compare_intent(a, b) when a == b, do: 1.0

  defp compare_intent(a, b) do
    positive = ["yes", "want_to", "definitely", "within_2_years", "within_5_years"]
    maybe = ["maybe", "someday", "not_sure", "undecided"]
    negative = ["no", "dont_want", "never"]

    cond do
      a in positive and b in positive -> 1.0
      a in maybe and b in maybe -> 0.7
      (a in positive and b in maybe) or (a in maybe and b in positive) -> 0.5
      a in negative and b in negative -> 0.7
      true -> 0.2
    end
  end

  # Adjacent prefecture lookup (simplified - major regions)
  @adjacent_prefectures %{
    "東京都" => ["神奈川県", "埼玉県", "千葉県", "山梨県"],
    "神奈川県" => ["東京都", "静岡県", "山梨県"],
    "埼玉県" => ["東京都", "千葉県", "茨城県", "栃木県", "群馬県"],
    "千葉県" => ["東京都", "埼玉県", "茨城県"],
    "大阪府" => ["京都府", "兵庫県", "奈良県", "和歌山県"],
    "京都府" => ["大阪府", "兵庫県", "奈良県", "滋賀県", "福井県"],
    "兵庫県" => ["大阪府", "京都府", "岡山県", "鳥取県"],
    "愛知県" => ["静岡県", "岐阜県", "三重県", "長野県"],
    "福岡県" => ["佐賀県", "熊本県", "大分県"],
    "北海道" => [],
    "宮城県" => ["岩手県", "秋田県", "山形県", "福島県"],
    "広島県" => ["岡山県", "山口県", "島根県", "鳥取県"]
  }

  defp adjacent_prefectures?(pref_a, pref_b) do
    neighbors_a = Map.get(@adjacent_prefectures, pref_a, [])
    neighbors_b = Map.get(@adjacent_prefectures, pref_b, [])
    pref_b in neighbors_a or pref_a in neighbors_b
  end
end
