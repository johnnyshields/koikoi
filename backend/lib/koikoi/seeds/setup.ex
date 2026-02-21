defmodule Koikoi.Seeds.Setup do
  @moduledoc """
  Database setup: creates MongoDB indexes for all collections.
  Run with: mix run -e "Koikoi.Seeds.Setup.run()"
  """

  require Logger

  def run do
    Logger.info("Setting up MongoDB indexes...")

    create_user_indexes()
    create_profile_indexes()
    create_phone_verification_indexes()
    create_match_indexes()
    create_like_indexes()
    create_tags_catalog_indexes()
    create_conversation_indexes()

    Logger.info("MongoDB indexes created successfully!")
  end

  defp create_user_indexes do
    Logger.info("Creating indexes for 'users' collection...")

    Mongo.create_indexes(:mongo, "users", [
      %{key: %{phone_number: 1}, name: "phone_number_unique", unique: true},
      %{key: %{invite_code: 1}, name: "invite_code_unique", unique: true},
      %{key: %{inserted_at: -1}, name: "inserted_at_desc"}
    ])
  end

  defp create_profile_indexes do
    Logger.info("Creating indexes for 'profiles' collection...")

    Mongo.create_indexes(:mongo, "profiles", [
      %{key: %{user_id: 1}, name: "user_id_unique", unique: true},
      %{key: %{gender: 1, age: 1}, name: "gender_age"},
      %{key: %{location: "2dsphere"}, name: "location_geo"},
      %{key: %{tag_ids: 1}, name: "tag_ids"},
      %{key: %{visibility: 1}, name: "visibility"},
      %{key: %{updated_at: -1}, name: "updated_at_desc"}
    ])
  end

  defp create_phone_verification_indexes do
    Logger.info("Creating indexes for 'phone_verifications' collection...")

    Mongo.create_indexes(:mongo, "phone_verifications", [
      %{key: %{phone_number: 1}, name: "phone_number_unique", unique: true},
      %{
        key: %{expires_at: 1},
        name: "expires_at_ttl",
        expireAfterSeconds: 0
      }
    ])
  end

  defp create_match_indexes do
    Logger.info("Creating indexes for 'matches' collection...")

    Mongo.create_indexes(:mongo, "matches", [
      %{
        key: %{person_a_id: 1, person_b_id: 1},
        name: "pair_unique",
        unique: true
      },
      %{key: %{person_a_id: 1, status: 1}, name: "person_a_status"},
      %{key: %{person_b_id: 1, status: 1}, name: "person_b_status"},
      %{key: %{matchmaker_id: 1}, name: "matchmaker_id"},
      %{key: %{status: 1, inserted_at: -1}, name: "status_created"}
    ])
  end

  defp create_like_indexes do
    Logger.info("Creating indexes for 'likes' collection...")

    Mongo.create_indexes(:mongo, "likes", [
      %{
        key: %{from_user_id: 1, to_user_id: 1},
        name: "from_to_unique",
        unique: true
      },
      %{key: %{to_user_id: 1, status: 1}, name: "to_user_status"},
      %{key: %{inserted_at: -1}, name: "inserted_at_desc"}
    ])
  end

  defp create_tags_catalog_indexes do
    Logger.info("Creating indexes for 'tags_catalog' collection...")

    Mongo.create_indexes(:mongo, "tags_catalog", [
      %{key: %{category: 1, slug: 1}, name: "category_slug_unique", unique: true},
      %{key: %{category: 1, sort_order: 1}, name: "category_sort"},
      %{key: %{slug: 1}, name: "slug"}
    ])
  end

  defp create_conversation_indexes do
    Logger.info("Creating indexes for 'conversations' and 'messages' collections...")

    Mongo.create_indexes(:mongo, "conversations", [
      %{key: %{match_id: 1}, name: "match_id_unique", unique: true},
      %{key: %{participant_ids: 1}, name: "participants"},
      %{key: %{last_message_at: -1}, name: "last_message_desc"}
    ])

    Mongo.create_indexes(:mongo, "messages", [
      %{key: %{conversation_id: 1, inserted_at: 1}, name: "conversation_timeline"},
      %{key: %{sender_id: 1}, name: "sender_id"}
    ])
  end
end
