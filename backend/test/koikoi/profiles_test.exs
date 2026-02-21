defmodule Koikoi.ProfilesTest do
  use ExUnit.Case, async: false

  import Koikoi.AccountHelpers

  alias Koikoi.Profiles
  alias Koikoi.Repo

  @moduletag :mongodb

  setup do
    Repo.delete_many("users", %{})
    Repo.delete_many("phone_verifications", %{})
    Repo.delete_many("profiles", %{})
    Repo.delete_many("tags_catalog", %{})

    # Clean up any test upload directories
    uploads_dir = Path.join([:code.priv_dir(:koikoi), "static", "uploads", "photos"])
    if File.exists?(uploads_dir), do: File.rm_rf!(uploads_dir)
    File.mkdir_p!(uploads_dir)

    :ok
  end

  defp create_user do
    create_test_user(%{"phone_number" => "+8190#{:rand.uniform(9_999_999)}"})
  end

  defp user_id(user), do: to_string(user["_id"])

  describe "create_profile/2" do
    test "creates a profile with basic attributes" do
      user = create_user()

      attrs = %{
        "nickname" => "Sakura",
        "location" => %{"prefecture" => "Tokyo", "city" => "Shibuya"},
        "bio" => "Hello!"
      }

      assert {:ok, profile} = Profiles.create_profile(user_id(user), attrs)
      assert profile["nickname"] == "Sakura"
      assert profile["location"]["prefecture"] == "Tokyo"
      assert profile["bio"] == "Hello!"
      assert is_float(profile["profile_completeness"])
      assert profile["profile_completeness"] > 0.0
    end

    test "rejects duplicate profile for same user" do
      user = create_user()
      attrs = %{"nickname" => "Sakura"}

      assert {:ok, _profile} = Profiles.create_profile(user_id(user), attrs)
      assert {:error, "profile_already_exists"} = Profiles.create_profile(user_id(user), attrs)
    end
  end

  describe "update_profile/2" do
    test "updates existing profile fields" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Sakura"})

      assert {:ok, updated} =
               Profiles.update_profile(user_id(user), %{
                 "nickname" => "Hana",
                 "bio" => "Updated bio"
               })

      assert updated["nickname"] == "Hana"
      assert updated["bio"] == "Updated bio"
    end

    test "returns not_found for nonexistent profile" do
      assert {:error, :not_found} = Profiles.update_profile("000000000000000000000000", %{})
    end
  end

  describe "get_profile/1" do
    test "returns profile for user" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      assert {:ok, profile} = Profiles.get_profile(user_id(user))
      assert profile["nickname"] == "Test"
    end

    test "returns not_found for missing profile" do
      assert {:error, :not_found} = Profiles.get_profile("000000000000000000000000")
    end
  end

  describe "calculate_completeness/1" do
    test "empty profile has 0% completeness" do
      profile = %{
        "nickname" => nil,
        "location" => %{},
        "photos" => [],
        "bio" => nil,
        "physical" => %{},
        "career" => %{},
        "lifestyle" => %{},
        "relationship" => %{},
        "tags" => [],
        "preferences" => %{}
      }

      assert Profiles.calculate_completeness(profile) == 0.0
    end

    test "fully filled profile has 100% completeness" do
      profile = %{
        "nickname" => "Sakura",
        "location" => %{"prefecture" => "Tokyo"},
        "photos" => [%{"id" => "1", "url" => "/test.jpg"}],
        "bio" => "Hello world",
        "physical" => %{"height_cm" => 165},
        "career" => %{"occupation" => "Engineer"},
        "lifestyle" => %{"drinking" => "sometimes"},
        "relationship" => %{"marriage_intent" => "yes"},
        "tags" => [
          %{"category" => "interests", "value" => "a"},
          %{"category" => "interests", "value" => "b"},
          %{"category" => "interests", "value" => "c"}
        ],
        "preferences" => %{"preferred_genders" => ["female"]}
      }

      assert Profiles.calculate_completeness(profile) == 1.0
    end

    test "partial profile has partial completeness" do
      profile = %{
        "nickname" => "Sakura",
        "location" => %{},
        "photos" => [],
        "bio" => nil,
        "physical" => %{},
        "career" => %{},
        "lifestyle" => %{},
        "relationship" => %{},
        "tags" => [],
        "preferences" => %{}
      }

      # nickname is 10%
      assert Profiles.calculate_completeness(profile) == 0.10
    end
  end

  describe "get_profile_for_viewer/2 - privacy filtering" do
    test "own profile returns full data" do
      user = create_user()

      {:ok, _} =
        Profiles.create_profile(user_id(user), %{
          "nickname" => "Sakura",
          "bio" => "Full bio here with lots of details about me"
        })

      assert {:ok, profile} = Profiles.get_profile_for_viewer(user_id(user), user_id(user))
      # Own profile should have all fields
      assert profile["nickname"] == "Sakura"
      assert profile["bio"] == "Full bio here with lots of details about me"
    end

    test "without Social module falls back to open tier (nickname + primary photo only)" do
      user1 = create_user()
      user2 = create_user()

      {:ok, _} =
        Profiles.create_profile(user_id(user1), %{
          "nickname" => "Sakura",
          "bio" => "My detailed bio"
        })

      assert {:ok, profile} = Profiles.get_profile_for_viewer(user_id(user1), user_id(user2))
      # Open tier: nickname and primary photo only
      assert profile["nickname"] == "Sakura"
      assert is_nil(profile["bio"])
    end
  end

  describe "photo management" do
    test "add_photo saves file and creates entry" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      file_data = %{
        content: "fake image data",
        filename: "test.jpg"
      }

      assert {:ok, photo} = Profiles.add_photo(user_id(user), file_data)
      assert is_binary(photo["id"])
      assert String.contains?(photo["url"], "/uploads/photos/")
      assert String.contains?(photo["thumbnail_url"], "thumb_")
      assert photo["is_primary"] == true
      assert photo["order"] == 0
    end

    test "second photo is not primary" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      file_data = %{content: "data1", filename: "a.jpg"}
      {:ok, _} = Profiles.add_photo(user_id(user), file_data)

      file_data2 = %{content: "data2", filename: "b.jpg"}
      {:ok, photo2} = Profiles.add_photo(user_id(user), file_data2)

      assert photo2["is_primary"] == false
      assert photo2["order"] == 1
    end

    test "max 6 photos enforced" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      for i <- 1..6 do
        file_data = %{content: "data#{i}", filename: "photo#{i}.jpg"}
        assert {:ok, _} = Profiles.add_photo(user_id(user), file_data)
      end

      file_data = %{content: "data7", filename: "photo7.jpg"}
      assert {:error, "max_photos_reached"} = Profiles.add_photo(user_id(user), file_data)
    end

    test "delete_photo removes photo" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      file_data = %{content: "data", filename: "test.jpg"}
      {:ok, photo} = Profiles.add_photo(user_id(user), file_data)

      assert :ok = Profiles.delete_photo(user_id(user), photo["id"])

      {:ok, profile} = Profiles.get_profile(user_id(user))
      assert Enum.empty?(profile["photos"])
    end

    test "set_primary_photo changes primary" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      {:ok, _p1} = Profiles.add_photo(user_id(user), %{content: "d1", filename: "a.jpg"})
      {:ok, p2} = Profiles.add_photo(user_id(user), %{content: "d2", filename: "b.jpg"})

      assert :ok = Profiles.set_primary_photo(user_id(user), p2["id"])

      {:ok, profile} = Profiles.get_profile(user_id(user))

      primary = Enum.find(profile["photos"], fn p -> p["is_primary"] end)
      assert primary["id"] == p2["id"]
    end

    test "reorder_photos changes order" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      {:ok, p1} = Profiles.add_photo(user_id(user), %{content: "d1", filename: "a.jpg"})
      {:ok, p2} = Profiles.add_photo(user_id(user), %{content: "d2", filename: "b.jpg"})

      assert {:ok, reordered} = Profiles.reorder_photos(user_id(user), [p2["id"], p1["id"]])
      assert Enum.at(reordered, 0)["id"] == p2["id"]
      assert Enum.at(reordered, 0)["order"] == 0
      assert Enum.at(reordered, 1)["id"] == p1["id"]
      assert Enum.at(reordered, 1)["order"] == 1
    end
  end

  describe "tag management" do
    test "add_tags adds tags to profile" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      tags = [
        %{"category" => "interests", "value" => "hiking"},
        %{"category" => "interests", "value" => "cooking"}
      ]

      assert {:ok, _updated_tags} = Profiles.add_tags(user_id(user), tags)

      {:ok, profile} = Profiles.get_profile(user_id(user))
      assert length(profile["tags"]) == 2
    end

    test "add_tags does not duplicate existing tags" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      tags = [%{"category" => "interests", "value" => "hiking"}]
      {:ok, _} = Profiles.add_tags(user_id(user), tags)
      {:ok, _} = Profiles.add_tags(user_id(user), tags)

      {:ok, profile} = Profiles.get_profile(user_id(user))
      assert length(profile["tags"]) == 1
    end

    test "remove_tag removes specific tag" do
      user = create_user()
      {:ok, _} = Profiles.create_profile(user_id(user), %{"nickname" => "Test"})

      tags = [
        %{"category" => "interests", "value" => "hiking"},
        %{"category" => "interests", "value" => "cooking"}
      ]

      {:ok, _} = Profiles.add_tags(user_id(user), tags)

      assert :ok =
               Profiles.remove_tag(user_id(user), %{
                 "category" => "interests",
                 "value" => "hiking"
               })

      {:ok, profile} = Profiles.get_profile(user_id(user))
      assert length(profile["tags"]) == 1
      assert Enum.at(profile["tags"], 0)["value"] == "cooking"
    end
  end

  describe "get_tags_catalog/1" do
    test "returns tags from catalog collection" do
      Repo.insert_one("tags_catalog", %{
        category: "interests",
        value: "ラーメン巡り",
        popularity: 100
      })

      Repo.insert_one("tags_catalog", %{
        category: "interests",
        value: "カフェ巡り",
        popularity: 80
      })

      tags = Profiles.get_tags_catalog(%{})
      assert length(tags) == 2
    end

    test "filters by category" do
      Repo.insert_one("tags_catalog", %{category: "interests", value: "hiking"})
      Repo.insert_one("tags_catalog", %{category: "personality", value: "calm"})

      tags = Profiles.get_tags_catalog(%{"category" => "interests"})
      assert length(tags) == 1
      assert Enum.at(tags, 0)["value"] == "hiking"
    end

    test "searches by value" do
      Repo.insert_one("tags_catalog", %{category: "interests", value: "hiking"})
      Repo.insert_one("tags_catalog", %{category: "interests", value: "cooking"})

      tags = Profiles.get_tags_catalog(%{"search" => "hik"})
      assert length(tags) == 1
    end
  end
end
