defmodule Koikoi.MatchingTest do
  use ExUnit.Case, async: false

  import Koikoi.AccountHelpers

  alias Koikoi.{Matching, Profiles, Social, Repo}
  alias Koikoi.Matching.{CompatibilityScorer, MatchAggregator}

  @moduletag :mongodb

  setup do
    Repo.delete_many("matchmaking_sessions", %{})
    Repo.delete_many("matches", %{})
    Repo.delete_many("connections", %{})
    Repo.delete_many("profiles", %{})
    Repo.delete_many("users", %{})
    :ok
  end

  defp id(user), do: to_string(user["_id"])

  defp create_user_with_profile(phone, gender, preferred_genders, tags \\ []) do
    user = create_test_user(%{"phone_number" => phone, "gender" => gender})
    user_id = id(user)

    {:ok, _profile} =
      Profiles.create_profile(user_id, %{
        "nickname" => "User #{phone}",
        "preferences" => %{
          "preferred_genders" => preferred_genders
        }
      })

    if tags != [] do
      {:ok, _} = Profiles.add_tags(user_id, tags)
    end

    user
  end

  defp setup_matchmaker_with_subjects(matchmaker, subjects) do
    Enum.each(subjects, fn subject ->
      {:ok, conn} = Social.invite_matchmaker(id(subject), id(matchmaker))
      {:ok, _} = Social.accept_matchmaker_invite(to_string(conn["_id"]), id(matchmaker))
    end)
  end

  defp make_friends(user_a, user_b) do
    {:ok, conn} = Social.send_friend_request(id(user_a), id(user_b))
    {:ok, _} = Social.accept_friend_request(to_string(conn["_id"]), id(user_b))
  end

  # --- Card Dealer Tests ---

  describe "deal_cards/1" do
    test "returns empty when matchmaker has no subjects" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      assert {:ok, []} = Matching.deal_cards(id(matchmaker))
    end

    test "returns empty when only one matchable subject" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})

      subject = create_user_with_profile("+81900000002", "female", ["male"])

      # Need 2 matchmakers for activation - add another matchmaker
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000099"})
      setup_matchmaker_with_subjects(matchmaker, [subject])
      setup_matchmaker_with_subjects(matchmaker2, [subject])

      assert {:ok, []} = Matching.deal_cards(id(matchmaker))
    end

    test "returns pairs for cross-preference users" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000099"})

      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      # Both need 2 matchmakers to be active
      setup_matchmaker_with_subjects(matchmaker, [user_a, user_b])
      setup_matchmaker_with_subjects(matchmaker2, [user_a, user_b])

      assert {:ok, pairs} = Matching.deal_cards(id(matchmaker))
      assert length(pairs) == 1

      pair = hd(pairs)
      assert pair.person_a.user_id != nil
      assert pair.person_b.user_id != nil
      assert is_float(pair.priority_score)
    end

    test "excludes pairs already rated by this matchmaker" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000099"})

      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      setup_matchmaker_with_subjects(matchmaker, [user_a, user_b])
      setup_matchmaker_with_subjects(matchmaker2, [user_a, user_b])

      # Rate the pair
      {:ok, _} =
        Matching.submit_rating(id(matchmaker), id(user_a), id(user_b), %{
          "rating" => 4,
          "confidence" => "medium"
        })

      assert {:ok, []} = Matching.deal_cards(id(matchmaker))
    end

    test "ensures canonical pair order (person_a_id < person_b_id)" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000099"})

      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      setup_matchmaker_with_subjects(matchmaker, [user_a, user_b])
      setup_matchmaker_with_subjects(matchmaker2, [user_a, user_b])

      {:ok, pairs} = Matching.deal_cards(id(matchmaker))

      Enum.each(pairs, fn pair ->
        assert pair.person_a.user_id < pair.person_b.user_id
      end)
    end

    test "includes shared tags in pair data" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000099"})

      shared_tags = [
        %{"category" => "hobby", "value" => "hiking"},
        %{"category" => "food", "value" => "sushi"}
      ]

      user_a =
        create_user_with_profile(
          "+81900000002",
          "female",
          ["male"],
          shared_tags ++
            [
              %{"category" => "music", "value" => "jazz"}
            ]
        )

      user_b =
        create_user_with_profile(
          "+81900000003",
          "male",
          ["female"],
          shared_tags ++
            [
              %{"category" => "music", "value" => "rock"}
            ]
        )

      setup_matchmaker_with_subjects(matchmaker, [user_a, user_b])
      setup_matchmaker_with_subjects(matchmaker2, [user_a, user_b])

      {:ok, pairs} = Matching.deal_cards(id(matchmaker))
      assert length(pairs) == 1

      pair = hd(pairs)
      shared_values = Enum.map(pair.shared_tags, & &1.value)
      assert "hiking" in shared_values
      assert "sushi" in shared_values
    end
  end

  # --- Compatibility Scorer Tests ---

  describe "calculate_score/2" do
    test "returns zero score with no ratings" do
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      result = CompatibilityScorer.calculate_score(id(user_a), id(user_b))

      assert result.score == 0.0
      assert result.total_ratings == 0
      assert result.human_ratings == 0
    end

    test "calculates score from human ratings" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      # Matchmaker becomes friends with users for tier weight
      make_friends(matchmaker, user_a)
      make_friends(matchmaker, user_b)

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      # Insert a rating of 5 (max)
      Repo.insert_one("matchmaking_sessions", %{
        matchmaker_id: to_oid(id(matchmaker)),
        person_a_id: to_oid(a_id),
        person_b_id: to_oid(b_id),
        rating: 5,
        confidence: "high",
        signals: %{},
        is_ai: false,
        skipped: false,
        inserted_at: now,
        updated_at: now
      })

      result = CompatibilityScorer.calculate_score(a_id, b_id)

      assert result.score == 1.0
      assert result.total_ratings == 1
      assert result.human_ratings == 1
      assert result.ai_ratings == 0
      assert result.strong_ratings == 1
    end

    test "AI ratings get 0.3 weight multiplier" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      Repo.insert_one("matchmaking_sessions", %{
        matchmaker_id: to_oid(id(matchmaker)),
        person_a_id: to_oid(a_id),
        person_b_id: to_oid(b_id),
        rating: 5,
        confidence: "medium",
        signals: %{},
        is_ai: true,
        skipped: false,
        inserted_at: now,
        updated_at: now
      })

      result = CompatibilityScorer.calculate_score(a_id, b_id)

      assert result.ai_ratings == 1
      assert result.human_ratings == 0
      # Score should still be 1.0 since we only have one rating
      assert result.score == 1.0
    end

    test "skipped sessions are excluded from scoring" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      Repo.insert_one("matchmaking_sessions", %{
        matchmaker_id: to_oid(id(matchmaker)),
        person_a_id: to_oid(a_id),
        person_b_id: to_oid(b_id),
        rating: nil,
        confidence: nil,
        signals: %{},
        is_ai: false,
        skipped: true,
        inserted_at: now,
        updated_at: now
      })

      result = CompatibilityScorer.calculate_score(a_id, b_id)

      assert result.score == 0.0
      assert result.total_ratings == 0
    end

    test "canonical pair order is enforced" do
      {a, b} = CompatibilityScorer.canonical_pair("zzz", "aaa")
      assert a == "aaa"
      assert b == "zzz"

      {a2, b2} = CompatibilityScorer.canonical_pair("aaa", "zzz")
      assert a2 == "aaa"
      assert b2 == "zzz"
    end
  end

  # --- Match Threshold Tests ---

  describe "check_and_create_match/2" do
    test "creates match when normal threshold met (3+ human, score >= 0.70, 2+ strong)" do
      matchmaker1 = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000010"})
      matchmaker3 = create_test_user(%{"phone_number" => "+81900000011"})
      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      # Make matchmakers friends with users for tier weight
      make_friends(matchmaker1, user_a)
      make_friends(matchmaker1, user_b)
      make_friends(matchmaker2, user_a)
      make_friends(matchmaker2, user_b)
      make_friends(matchmaker3, user_a)
      make_friends(matchmaker3, user_b)

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      # Submit 3 high ratings
      for mm <- [matchmaker1, matchmaker2, matchmaker3] do
        Repo.insert_one("matchmaking_sessions", %{
          matchmaker_id: to_oid(id(mm)),
          person_a_id: to_oid(a_id),
          person_b_id: to_oid(b_id),
          rating: 5,
          confidence: "high",
          signals: %{},
          is_ai: false,
          skipped: false,
          inserted_at: now,
          updated_at: now
        })
      end

      assert {:ok, {:match_created, match}} =
               MatchAggregator.check_and_create_match(a_id, b_id)

      assert match["status"] == "pending_intro"
      assert match["match_type"] == "normal"
      assert match["compatibility_score"] >= 0.70
    end

    test "does not create match below threshold" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      # Only 1 rating - not enough
      Repo.insert_one("matchmaking_sessions", %{
        matchmaker_id: to_oid(id(matchmaker)),
        person_a_id: to_oid(a_id),
        person_b_id: to_oid(b_id),
        rating: 5,
        confidence: "high",
        signals: %{},
        is_ai: false,
        skipped: false,
        inserted_at: now,
        updated_at: now
      })

      assert {:ok, :below_threshold} = MatchAggregator.check_and_create_match(a_id, b_id)
    end

    test "cold start threshold (2 human + 1 AI, score >= 0.75, 2+ strong)" do
      matchmaker1 = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000010"})
      ai_matchmaker = create_test_user(%{"phone_number" => "+81900000011"})
      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      make_friends(matchmaker1, user_a)
      make_friends(matchmaker1, user_b)
      make_friends(matchmaker2, user_a)
      make_friends(matchmaker2, user_b)

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      # 2 human high ratings
      for mm <- [matchmaker1, matchmaker2] do
        Repo.insert_one("matchmaking_sessions", %{
          matchmaker_id: to_oid(id(mm)),
          person_a_id: to_oid(a_id),
          person_b_id: to_oid(b_id),
          rating: 5,
          confidence: "high",
          signals: %{},
          is_ai: false,
          skipped: false,
          inserted_at: now,
          updated_at: now
        })
      end

      # 1 AI rating
      Repo.insert_one("matchmaking_sessions", %{
        matchmaker_id: to_oid(id(ai_matchmaker)),
        person_a_id: to_oid(a_id),
        person_b_id: to_oid(b_id),
        rating: 5,
        confidence: "high",
        signals: %{},
        is_ai: true,
        skipped: false,
        inserted_at: now,
        updated_at: now
      })

      assert {:ok, {:match_created, match}} =
               MatchAggregator.check_and_create_match(a_id, b_id)

      assert match["match_type"] == "cold_start"
    end

    test "does not create duplicate matches" do
      matchmaker1 = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000010"})
      matchmaker3 = create_test_user(%{"phone_number" => "+81900000011"})
      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      make_friends(matchmaker1, user_a)
      make_friends(matchmaker1, user_b)
      make_friends(matchmaker2, user_a)
      make_friends(matchmaker2, user_b)
      make_friends(matchmaker3, user_a)
      make_friends(matchmaker3, user_b)

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      for mm <- [matchmaker1, matchmaker2, matchmaker3] do
        Repo.insert_one("matchmaking_sessions", %{
          matchmaker_id: to_oid(id(mm)),
          person_a_id: to_oid(a_id),
          person_b_id: to_oid(b_id),
          rating: 5,
          confidence: "high",
          signals: %{},
          is_ai: false,
          skipped: false,
          inserted_at: now,
          updated_at: now
        })
      end

      assert {:ok, {:match_created, _}} = MatchAggregator.check_and_create_match(a_id, b_id)
      assert {:ok, :already_matched} = MatchAggregator.check_and_create_match(a_id, b_id)
    end
  end

  # --- Introduction Flow Tests ---

  describe "respond_to_match/3" do
    setup do
      matchmaker1 = create_test_user(%{"phone_number" => "+81900000001"})
      matchmaker2 = create_test_user(%{"phone_number" => "+81900000010"})
      matchmaker3 = create_test_user(%{"phone_number" => "+81900000011"})
      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      make_friends(matchmaker1, user_a)
      make_friends(matchmaker1, user_b)
      make_friends(matchmaker2, user_a)
      make_friends(matchmaker2, user_b)
      make_friends(matchmaker3, user_a)
      make_friends(matchmaker3, user_b)

      now = DateTime.utc_now()
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      for mm <- [matchmaker1, matchmaker2, matchmaker3] do
        Repo.insert_one("matchmaking_sessions", %{
          matchmaker_id: to_oid(id(mm)),
          person_a_id: to_oid(a_id),
          person_b_id: to_oid(b_id),
          rating: 5,
          confidence: "high",
          signals: %{},
          is_ai: false,
          skipped: false,
          inserted_at: now,
          updated_at: now
        })
      end

      {:ok, {:match_created, match}} = MatchAggregator.check_and_create_match(a_id, b_id)
      match_id = to_string(match["_id"])

      %{user_a: user_a, user_b: user_b, match_id: match_id}
    end

    test "person_a can accept", %{user_a: user_a, match_id: match_id} do
      {:ok, updated} = Matching.respond_to_match(match_id, id(user_a), "accepted")
      assert updated["person_a_response"] == "accepted"
      assert updated["status"] == "pending_intro"
    end

    test "person_b can accept", %{user_b: user_b, match_id: match_id} do
      {:ok, updated} = Matching.respond_to_match(match_id, id(user_b), "accepted")
      assert updated["person_b_response"] == "accepted"
      assert updated["status"] == "pending_intro"
    end

    test "both accepting transitions to introduced", %{
      user_a: user_a,
      user_b: user_b,
      match_id: match_id
    } do
      {:ok, _} = Matching.respond_to_match(match_id, id(user_a), "accepted")
      {:ok, updated} = Matching.respond_to_match(match_id, id(user_b), "accepted")
      assert updated["status"] == "introduced"
    end

    test "decline transitions to declined immediately", %{user_a: user_a, match_id: match_id} do
      {:ok, updated} = Matching.respond_to_match(match_id, id(user_a), "declined")
      assert updated["status"] == "declined"
    end

    test "unauthorized user cannot respond", %{match_id: match_id} do
      stranger = create_test_user(%{"phone_number" => "+81900000099"})

      assert {:error, :unauthorized} =
               Matching.respond_to_match(match_id, id(stranger), "accepted")
    end

    test "invalid response is rejected", %{user_a: user_a, match_id: match_id} do
      assert {:error, "invalid_response"} =
               Matching.respond_to_match(match_id, id(user_a), "maybe")
    end
  end

  # --- Submit Rating Integration Tests ---

  describe "submit_rating/4" do
    test "creates session and checks for match" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_user_with_profile("+81900000002", "female", ["male"])
      user_b = create_user_with_profile("+81900000003", "male", ["female"])

      {:ok, result} =
        Matching.submit_rating(id(matchmaker), id(user_a), id(user_b), %{
          "rating" => 4,
          "confidence" => "medium",
          "note" => "They seem compatible"
        })

      assert result.session["rating"] == 4
      assert result.session["confidence"] == "medium"
      assert result.session["skipped"] == false
    end

    test "rejects invalid rating" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      assert {:error, "invalid_rating"} =
               Matching.submit_rating(id(matchmaker), id(user_a), id(user_b), %{
                 "rating" => 6
               })

      assert {:error, "invalid_rating"} =
               Matching.submit_rating(id(matchmaker), id(user_a), id(user_b), %{
                 "rating" => 0
               })
    end
  end

  # --- Skip Pair Tests ---

  describe "skip_pair/3" do
    test "records a skipped session" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      assert :ok = Matching.skip_pair(id(matchmaker), id(user_a), id(user_b))

      # Verify session was created
      {a_id, b_id} = CompatibilityScorer.canonical_pair(id(user_a), id(user_b))

      session =
        Repo.find_one("matchmaking_sessions", %{
          matchmaker_id: to_oid(id(matchmaker)),
          person_a_id: to_oid(a_id),
          person_b_id: to_oid(b_id)
        })

      assert session["skipped"] == true
      assert session["rating"] == nil
    end
  end

  # --- Matchmaker Stats Tests ---

  describe "get_matchmaker_stats/1" do
    test "returns stats for a matchmaker" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})

      {:ok, stats} = Matching.get_matchmaker_stats(id(matchmaker))

      assert stats.total_ratings == 0
      assert stats.total_skipped == 0
      assert stats.successful_matches == 0
      assert stats.rating_average == 0.0
    end

    test "reflects submitted ratings" do
      matchmaker = create_test_user(%{"phone_number" => "+81900000001"})
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      Matching.submit_rating(id(matchmaker), id(user_a), id(user_b), %{
        "rating" => 4,
        "confidence" => "medium"
      })

      {:ok, stats} = Matching.get_matchmaker_stats(id(matchmaker))

      assert stats.total_ratings == 1
      assert stats.rating_average == 4.0
    end
  end

  # --- List/Get Matches Tests ---

  describe "list_matches/2" do
    test "returns matches where user is a participant" do
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      now = DateTime.utc_now()
      expires_at = DateTime.add(now, 72 * 3600, :second)

      Repo.insert_one("matches", %{
        person_a_id: to_oid(id(user_a)),
        person_b_id: to_oid(id(user_b)),
        status: "pending_intro",
        compatibility_score: 0.85,
        total_ratings: 3,
        match_type: "normal",
        signal_summary: %{},
        person_a_response: nil,
        person_b_response: nil,
        conversation_id: nil,
        expires_at: expires_at,
        inserted_at: now,
        updated_at: now
      })

      {:ok, matches} = Matching.list_matches(id(user_a))
      assert length(matches) == 1

      {:ok, matches_b} = Matching.list_matches(id(user_b))
      assert length(matches_b) == 1
    end

    test "filters by status" do
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      now = DateTime.utc_now()
      expires_at = DateTime.add(now, 72 * 3600, :second)

      Repo.insert_one("matches", %{
        person_a_id: to_oid(id(user_a)),
        person_b_id: to_oid(id(user_b)),
        status: "pending_intro",
        compatibility_score: 0.85,
        total_ratings: 3,
        match_type: "normal",
        signal_summary: %{},
        person_a_response: nil,
        person_b_response: nil,
        conversation_id: nil,
        expires_at: expires_at,
        inserted_at: now,
        updated_at: now
      })

      {:ok, pending} = Matching.list_matches(id(user_a), status: "pending_intro")
      assert length(pending) == 1

      {:ok, introduced} = Matching.list_matches(id(user_a), status: "introduced")
      assert length(introduced) == 0
    end
  end

  describe "get_match/2" do
    test "returns match for participant" do
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})

      now = DateTime.utc_now()
      expires_at = DateTime.add(now, 72 * 3600, :second)

      {:ok, result} =
        Repo.insert_one("matches", %{
          person_a_id: to_oid(id(user_a)),
          person_b_id: to_oid(id(user_b)),
          status: "pending_intro",
          compatibility_score: 0.85,
          total_ratings: 3,
          match_type: "normal",
          signal_summary: %{},
          person_a_response: nil,
          person_b_response: nil,
          conversation_id: nil,
          expires_at: expires_at,
          inserted_at: now,
          updated_at: now
        })

      match_id = to_string(result.inserted_id)

      {:ok, match} = Matching.get_match(match_id, id(user_a))
      assert match["status"] == "pending_intro"
    end

    test "returns unauthorized for non-participant" do
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      user_b = create_test_user(%{"phone_number" => "+81900000003"})
      stranger = create_test_user(%{"phone_number" => "+81900000099"})

      now = DateTime.utc_now()
      expires_at = DateTime.add(now, 72 * 3600, :second)

      {:ok, result} =
        Repo.insert_one("matches", %{
          person_a_id: to_oid(id(user_a)),
          person_b_id: to_oid(id(user_b)),
          status: "pending_intro",
          compatibility_score: 0.85,
          total_ratings: 3,
          match_type: "normal",
          signal_summary: %{},
          person_a_response: nil,
          person_b_response: nil,
          conversation_id: nil,
          expires_at: expires_at,
          inserted_at: now,
          updated_at: now
        })

      match_id = to_string(result.inserted_id)
      assert {:error, :unauthorized} = Matching.get_match(match_id, id(stranger))
    end

    test "returns not_found for invalid match_id" do
      user_a = create_test_user(%{"phone_number" => "+81900000002"})
      fake_id = "507f1f77bcf86cd799439011"

      assert {:error, :not_found} = Matching.get_match(fake_id, id(user_a))
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
