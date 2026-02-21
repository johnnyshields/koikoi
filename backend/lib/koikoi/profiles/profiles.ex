defmodule Koikoi.Profiles do
  @moduledoc """
  The Profiles context manages user profiles, photos, tags, and privacy filtering.
  Profiles are stored in a separate `profiles` collection from `users` for security isolation.
  """

  alias Koikoi.Repo

  @profiles_collection "profiles"
  @tags_catalog_collection "tags_catalog"
  @max_photos 6

  # --- Profile CRUD ---

  def create_profile(user_id, attrs) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        now = DateTime.utc_now()

        document =
          build_profile_document(attrs)
          |> Map.merge(%{
            user_id: oid,
            photos: [],
            tags: [],
            visibility: Map.get(attrs, "visibility", %{}),
            preferences: build_preferences(Map.get(attrs, "preferences", %{})),
            inserted_at: now,
            updated_at: now
          })

        document = Map.put(document, :profile_completeness, calculate_completeness(document))

        case Repo.insert_one(@profiles_collection, document) do
          {:ok, result} ->
            profile = Repo.find_one(@profiles_collection, %{_id: result.inserted_id})
            {:ok, profile}

          {:error, reason} ->
            {:error, reason}
        end

      _existing ->
        {:error, "profile_already_exists"}
    end
  end

  def update_profile(user_id, attrs) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        {:error, :not_found}

      profile ->
        updates = build_update_fields(attrs)
        now = DateTime.utc_now()

        # Calculate new completeness with merged fields
        merged =
          profile
          |> Map.merge(updates)
          |> Map.put("photos", profile["photos"] || [])
          |> Map.put("tags", profile["tags"] || [])

        completeness = calculate_completeness(merged)

        set_fields =
          updates
          |> Map.put(:profile_completeness, completeness)
          |> Map.put(:updated_at, now)

        Repo.update_one(
          @profiles_collection,
          %{user_id: oid},
          %{"$set" => set_fields}
        )

        {:ok, Repo.find_one(@profiles_collection, %{user_id: oid})}
    end
  end

  def get_profile(user_id) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil -> {:error, :not_found}
      profile -> {:ok, profile}
    end
  end

  def get_profile_for_viewer(profile_user_id, viewer_user_id) do
    if to_string(profile_user_id) == to_string(viewer_user_id) do
      get_profile(profile_user_id)
    else
      with {:ok, profile} <- get_profile(profile_user_id) do
        tier = get_trust_tier(profile_user_id, viewer_user_id)
        {:ok, filter_profile_by_tier(profile, tier, profile_user_id)}
      end
    end
  end

  # --- Profile Completeness ---

  def calculate_completeness(profile) do
    scores = [
      {0.10, has_value?(profile, "nickname")},
      {0.10, has_location?(profile)},
      {0.20, has_photo?(profile)},
      {0.10, has_value?(profile, "bio")},
      {0.10, has_physical?(profile)},
      {0.10, has_career?(profile)},
      {0.05, has_lifestyle?(profile)},
      {0.10, has_relationship?(profile)},
      {0.10, has_tags?(profile)},
      {0.05, has_preferences?(profile)}
    ]

    scores
    |> Enum.reduce(0.0, fn {weight, present}, acc ->
      if present, do: acc + weight, else: acc
    end)
    |> Float.round(2)
  end

  # --- Photo Management ---

  def add_photo(user_id, file_data) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        {:error, :not_found}

      profile ->
        photos = profile["photos"] || []

        if length(photos) >= @max_photos do
          {:error, "max_photos_reached"}
        else
          photo_id = generate_id()
          ext = get_file_extension(file_data)
          filename = "#{photo_id}.#{ext}"
          user_id_str = to_string(user_id)
          dir = photo_upload_dir(user_id_str)
          File.mkdir_p!(dir)

          file_path = Path.join(dir, filename)
          thumb_path = Path.join(dir, "thumb_#{filename}")

          # Write file
          :ok = File.write(file_path, file_data.content)
          # Thumbnail: just copy for now
          :ok = File.write(thumb_path, file_data.content)

          is_primary = Enum.empty?(photos)

          photo_entry = %{
            "id" => photo_id,
            "url" => "/uploads/photos/#{user_id_str}/#{filename}",
            "thumbnail_url" => "/uploads/photos/#{user_id_str}/thumb_#{filename}",
            "order" => length(photos),
            "is_primary" => is_primary
          }

          Repo.update_one(
            @profiles_collection,
            %{user_id: oid},
            %{
              "$push" => %{photos: photo_entry},
              "$set" => %{updated_at: DateTime.utc_now()}
            }
          )

          # Recalculate completeness
          updated_profile = Repo.find_one(@profiles_collection, %{user_id: oid})
          completeness = calculate_completeness(updated_profile)

          Repo.update_one(
            @profiles_collection,
            %{user_id: oid},
            %{"$set" => %{profile_completeness: completeness}}
          )

          {:ok, photo_entry}
        end
    end
  end

  def delete_photo(user_id, photo_id) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        {:error, :not_found}

      profile ->
        photos = profile["photos"] || []
        photo = Enum.find(photos, fn p -> p["id"] == photo_id end)

        if photo do
          # Delete files
          user_id_str = to_string(user_id)
          url_filename = Path.basename(photo["url"])
          thumb_filename = Path.basename(photo["thumbnail_url"])
          dir = photo_upload_dir(user_id_str)

          File.rm(Path.join(dir, url_filename))
          File.rm(Path.join(dir, thumb_filename))

          # Remove from array
          Repo.update_one(
            @profiles_collection,
            %{user_id: oid},
            %{
              "$pull" => %{photos: %{"id" => photo_id}},
              "$set" => %{updated_at: DateTime.utc_now()}
            }
          )

          # If deleted photo was primary, set the first remaining as primary
          remaining =
            photos
            |> Enum.reject(fn p -> p["id"] == photo_id end)
            |> Enum.with_index()
            |> Enum.map(fn {p, i} -> Map.merge(p, %{"order" => i}) end)

          remaining =
            if photo["is_primary"] && length(remaining) > 0 do
              List.update_at(remaining, 0, fn p -> Map.put(p, "is_primary", true) end)
            else
              remaining
            end

          Repo.update_one(
            @profiles_collection,
            %{user_id: oid},
            %{"$set" => %{photos: remaining}}
          )

          # Recalculate completeness
          updated_profile = Repo.find_one(@profiles_collection, %{user_id: oid})
          completeness = calculate_completeness(updated_profile)

          Repo.update_one(
            @profiles_collection,
            %{user_id: oid},
            %{"$set" => %{profile_completeness: completeness}}
          )

          :ok
        else
          {:error, :not_found}
        end
    end
  end

  def reorder_photos(user_id, photo_ids) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        {:error, :not_found}

      profile ->
        photos = profile["photos"] || []
        photo_map = Map.new(photos, fn p -> {p["id"], p} end)

        reordered =
          photo_ids
          |> Enum.with_index()
          |> Enum.map(fn {id, i} ->
            case Map.get(photo_map, id) do
              nil -> nil
              p -> Map.put(p, "order", i)
            end
          end)
          |> Enum.reject(&is_nil/1)

        Repo.update_one(
          @profiles_collection,
          %{user_id: oid},
          %{"$set" => %{photos: reordered, updated_at: DateTime.utc_now()}}
        )

        {:ok, reordered}
    end
  end

  def set_primary_photo(user_id, photo_id) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        {:error, :not_found}

      profile ->
        photos = profile["photos"] || []

        if Enum.any?(photos, fn p -> p["id"] == photo_id end) do
          updated_photos =
            Enum.map(photos, fn p ->
              Map.put(p, "is_primary", p["id"] == photo_id)
            end)

          Repo.update_one(
            @profiles_collection,
            %{user_id: oid},
            %{"$set" => %{photos: updated_photos, updated_at: DateTime.utc_now()}}
          )

          :ok
        else
          {:error, :not_found}
        end
    end
  end

  # --- Tag Management ---

  def add_tags(user_id, tags) when is_list(tags) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        {:error, :not_found}

      _profile ->
        normalized_tags =
          Enum.map(tags, fn tag ->
            %{"category" => tag["category"], "value" => tag["value"]}
          end)

        Repo.update_one(
          @profiles_collection,
          %{user_id: oid},
          %{
            "$addToSet" => %{tags: %{"$each" => normalized_tags}},
            "$set" => %{updated_at: DateTime.utc_now()}
          }
        )

        # Recalculate completeness
        updated_profile = Repo.find_one(@profiles_collection, %{user_id: oid})
        completeness = calculate_completeness(updated_profile)

        Repo.update_one(
          @profiles_collection,
          %{user_id: oid},
          %{"$set" => %{profile_completeness: completeness}}
        )

        {:ok, updated_profile["tags"]}
    end
  end

  def remove_tag(user_id, tag) do
    oid = to_object_id(user_id)

    case Repo.find_one(@profiles_collection, %{user_id: oid}) do
      nil ->
        {:error, :not_found}

      _profile ->
        Repo.update_one(
          @profiles_collection,
          %{user_id: oid},
          %{
            "$pull" => %{
              tags: %{"category" => tag["category"], "value" => tag["value"]}
            },
            "$set" => %{updated_at: DateTime.utc_now()}
          }
        )

        # Recalculate completeness
        updated_profile = Repo.find_one(@profiles_collection, %{user_id: oid})
        completeness = calculate_completeness(updated_profile)

        Repo.update_one(
          @profiles_collection,
          %{user_id: oid},
          %{"$set" => %{profile_completeness: completeness}}
        )

        :ok
    end
  end

  def get_tags_catalog(opts \\ %{}) do
    filter =
      %{}
      |> maybe_add_filter("category", opts["category"])
      |> maybe_add_search_filter(opts["search"])

    limit = parse_limit(opts["limit"], 50)

    Repo.find(@tags_catalog_collection, filter, limit: limit)
    |> Enum.to_list()
  end

  # --- Privacy Filtering ---

  defp get_trust_tier(profile_user_id, viewer_user_id) do
    if Code.ensure_loaded?(Koikoi.Social) &&
         function_exported?(Koikoi.Social, :get_trust_tier, 2) do
      Koikoi.Social.get_trust_tier(
        to_string(profile_user_id),
        to_string(viewer_user_id)
      )
    else
      "open"
    end
  end

  defp filter_profile_by_tier(profile, "inner_circle", _profile_user_id) do
    profile
  end

  defp filter_profile_by_tier(profile, "friends", profile_user_id) do
    age = calculate_age(profile_user_id)
    photos = profile["photos"] || []
    primary_photo = Enum.find(photos, fn p -> p["is_primary"] end)
    tags = Enum.take(profile["tags"] || [], 5)
    bio = truncate_string(profile["bio"], 100)

    %{
      "user_id" => profile["user_id"],
      "nickname" => profile["nickname"],
      "photos" => if(primary_photo, do: [primary_photo], else: []),
      "location" => %{"prefecture" => get_in(profile, ["location", "prefecture"])},
      "tags" => tags,
      "bio" => bio,
      "age" => age,
      "physical" => %{"height_cm" => get_in(profile, ["physical", "height_cm"])},
      "profile_completeness" => profile["profile_completeness"]
    }
  end

  defp filter_profile_by_tier(profile, "verified", profile_user_id) do
    age = calculate_age(profile_user_id)
    photos = profile["photos"] || []
    primary_photo = Enum.find(photos, fn p -> p["is_primary"] end)

    %{
      "user_id" => profile["user_id"],
      "nickname" => profile["nickname"],
      "photos" => if(primary_photo, do: [primary_photo], else: []),
      "location" => %{"prefecture" => get_in(profile, ["location", "prefecture"])},
      "age" => age
    }
  end

  defp filter_profile_by_tier(profile, _tier, _profile_user_id) do
    photos = profile["photos"] || []
    primary_photo = Enum.find(photos, fn p -> p["is_primary"] end)

    %{
      "user_id" => profile["user_id"],
      "nickname" => profile["nickname"],
      "photos" => if(primary_photo, do: [primary_photo], else: [])
    }
  end

  defp calculate_age(user_id) do
    user = Koikoi.Accounts.get_user(to_string(user_id))

    case user do
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

  # --- Private Helpers ---

  defp build_profile_document(attrs) do
    %{
      nickname: attrs["nickname"],
      location: build_nested(attrs["location"], ["prefecture", "city"]),
      hometown: attrs["hometown"],
      physical: build_nested(attrs["physical"], ["height_cm", "body_type", "blood_type"]),
      career: build_nested(attrs["career"], ["occupation", "education", "income_range"]),
      lifestyle: build_nested(attrs["lifestyle"], ["drinking", "smoking"]),
      relationship:
        build_nested(attrs["relationship"], ["marriage_intent", "has_children", "wants_children"]),
      personality: attrs["personality"],
      bio: attrs["bio"]
    }
  end

  defp build_update_fields(attrs) do
    fields = %{}

    fields = maybe_put(fields, :nickname, attrs["nickname"])
    fields = maybe_put(fields, :hometown, attrs["hometown"])
    fields = maybe_put(fields, :personality, attrs["personality"])
    fields = maybe_put(fields, :bio, attrs["bio"])

    fields = maybe_put_nested(fields, :location, attrs["location"], ["prefecture", "city"])

    fields =
      maybe_put_nested(fields, :physical, attrs["physical"], [
        "height_cm",
        "body_type",
        "blood_type"
      ])

    fields =
      maybe_put_nested(fields, :career, attrs["career"], [
        "occupation",
        "education",
        "income_range"
      ])

    fields = maybe_put_nested(fields, :lifestyle, attrs["lifestyle"], ["drinking", "smoking"])

    fields =
      maybe_put_nested(fields, :relationship, attrs["relationship"], [
        "marriage_intent",
        "has_children",
        "wants_children"
      ])

    fields =
      maybe_put_nested(fields, :visibility, attrs["visibility"], ["income_range", "body_type"])

    fields =
      if attrs["preferences"] do
        Map.put(fields, :preferences, build_preferences(attrs["preferences"]))
      else
        fields
      end

    fields
  end

  defp build_nested(nil, _keys), do: %{}

  defp build_nested(map, keys) when is_map(map) do
    Map.new(keys, fn key ->
      {String.to_atom(key), Map.get(map, key)}
    end)
  end

  defp build_nested(_other, _keys), do: %{}

  defp maybe_put(fields, _key, nil), do: fields
  defp maybe_put(fields, key, value), do: Map.put(fields, key, value)

  defp maybe_put_nested(fields, _key, nil, _keys), do: fields

  defp maybe_put_nested(fields, key, map, keys) when is_map(map) do
    Map.put(fields, key, build_nested(map, keys))
  end

  defp maybe_put_nested(fields, _key, _other, _keys), do: fields

  defp build_preferences(nil),
    do: %{age_range: nil, preferred_genders: [], preferred_prefectures: nil}

  defp build_preferences(prefs) when is_map(prefs) do
    %{
      age_range: build_age_range(prefs["age_range"]),
      preferred_genders: prefs["preferred_genders"] || [],
      preferred_prefectures: prefs["preferred_prefectures"]
    }
  end

  defp build_preferences(_),
    do: %{age_range: nil, preferred_genders: [], preferred_prefectures: nil}

  defp build_age_range(nil), do: nil

  defp build_age_range(range) when is_map(range) do
    %{min: range["min"], max: range["max"]}
  end

  defp build_age_range(_), do: nil

  # --- Completeness Checks ---

  defp has_value?(profile, key) do
    val = profile[key] || profile[String.to_atom(key)]
    is_binary(val) && String.trim(val) != ""
  end

  defp has_location?(profile) do
    loc = profile["location"] || profile[:location] || %{}
    prefecture = loc["prefecture"] || loc[:prefecture]
    is_binary(prefecture) && String.trim(prefecture) != ""
  end

  defp has_photo?(profile) do
    photos = profile["photos"] || profile[:photos] || []
    length(photos) >= 1
  end

  defp has_physical?(profile) do
    phys = profile["physical"] || profile[:physical] || %{}

    Enum.any?(["height_cm", "body_type", "blood_type"], fn key ->
      val = phys[key] || phys[String.to_atom(key)]
      val != nil && val != ""
    end)
  end

  defp has_career?(profile) do
    career = profile["career"] || profile[:career] || %{}

    Enum.any?(["occupation", "education", "income_range"], fn key ->
      val = career[key] || career[String.to_atom(key)]
      is_binary(val) && String.trim(val) != ""
    end)
  end

  defp has_lifestyle?(profile) do
    ls = profile["lifestyle"] || profile[:lifestyle] || %{}

    Enum.any?(["drinking", "smoking"], fn key ->
      val = ls[key] || ls[String.to_atom(key)]
      is_binary(val) && String.trim(val) != ""
    end)
  end

  defp has_relationship?(profile) do
    rel = profile["relationship"] || profile[:relationship] || %{}

    Enum.any?(["marriage_intent", "has_children", "wants_children"], fn key ->
      val = rel[key] || rel[String.to_atom(key)]
      val != nil && val != ""
    end)
  end

  defp has_tags?(profile) do
    tags = profile["tags"] || profile[:tags] || []
    length(tags) >= 3
  end

  defp has_preferences?(profile) do
    prefs = profile["preferences"] || profile[:preferences] || %{}
    genders = prefs["preferred_genders"] || prefs[:preferred_genders] || []
    length(genders) > 0
  end

  # --- Utility ---

  defp to_object_id(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, oid} -> oid
      :error -> id
    end
  end

  defp to_object_id(%BSON.ObjectId{} = oid), do: oid
  defp to_object_id(id), do: id

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp get_file_extension(%{filename: filename}) when is_binary(filename) do
    case Path.extname(filename) do
      "." <> ext -> String.downcase(ext)
      _ -> "jpg"
    end
  end

  defp get_file_extension(_), do: "jpg"

  defp photo_upload_dir(user_id_str) do
    Path.join([:code.priv_dir(:koikoi), "static", "uploads", "photos", user_id_str])
  end

  defp truncate_string(nil, _max), do: nil

  defp truncate_string(str, max) when is_binary(str) do
    if String.length(str) > max do
      String.slice(str, 0, max) <> "..."
    else
      str
    end
  end

  defp maybe_add_filter(filter, _key, nil), do: filter
  defp maybe_add_filter(filter, _key, ""), do: filter
  defp maybe_add_filter(filter, key, value), do: Map.put(filter, key, value)

  defp maybe_add_search_filter(filter, nil), do: filter
  defp maybe_add_search_filter(filter, ""), do: filter

  defp maybe_add_search_filter(filter, search) do
    Map.put(filter, "value", %{"$regex" => Regex.escape(search), "$options" => "i"})
  end

  defp parse_limit(nil, default), do: default
  defp parse_limit(val, _default) when is_integer(val) and val > 0, do: val

  defp parse_limit(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_limit(_, default), do: default
end
