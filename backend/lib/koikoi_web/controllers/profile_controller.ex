defmodule KoikoiWeb.ProfileController do
  use KoikoiWeb, :controller

  alias Koikoi.Profiles

  action_fallback KoikoiWeb.FallbackController

  # GET /api/v1/profile - Get own profile
  def show(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Profiles.get_profile(user_id) do
      {:ok, profile} ->
        json(conn, %{profile: serialize_profile(profile)})

      {:error, :not_found} ->
        json(conn, %{profile: nil})
    end
  end

  # PUT /api/v1/profile - Create or update own profile
  def update(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    result =
      case Profiles.get_profile(user_id) do
        {:ok, _profile} ->
          Profiles.update_profile(user_id, params)

        {:error, :not_found} ->
          Profiles.create_profile(user_id, params)
      end

    case result do
      {:ok, profile} ->
        json(conn, %{profile: serialize_profile(profile)})

      {:error, reason} ->
        {:error, reason}
    end
  end

  # GET /api/v1/profiles/:user_id - View another user's profile
  def show_other(conn, %{"user_id" => target_user_id}) do
    user = Guardian.Plug.current_resource(conn)
    viewer_id = to_string(user["_id"])

    with {:ok, profile} <- Profiles.get_profile_for_viewer(target_user_id, viewer_id) do
      json(conn, %{profile: serialize_profile(profile)})
    end
  end

  # POST /api/v1/profile/photos - Upload photo
  def upload_photo(conn, %{"photo" => %Plug.Upload{} = upload}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    content = File.read!(upload.path)

    file_data = %{
      content: content,
      filename: upload.filename,
      content_type: upload.content_type
    }

    with {:ok, photo} <- Profiles.add_photo(user_id, file_data) do
      conn
      |> put_status(:created)
      |> json(%{photo: photo})
    end
  end

  def upload_photo(_conn, _params) do
    {:error, "photo_required"}
  end

  # DELETE /api/v1/profile/photos/:photo_id - Delete photo
  def delete_photo(conn, %{"photo_id" => photo_id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Profiles.delete_photo(user_id, photo_id) do
      :ok -> json(conn, %{message: "photo_deleted"})
      {:error, reason} -> {:error, reason}
    end
  end

  # PUT /api/v1/profile/photos/reorder - Reorder photos
  def reorder_photos(conn, %{"photo_ids" => photo_ids}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    with {:ok, photos} <- Profiles.reorder_photos(user_id, photo_ids) do
      json(conn, %{photos: photos})
    end
  end

  # PUT /api/v1/profile/photos/:photo_id/primary - Set primary photo
  def set_primary(conn, %{"photo_id" => photo_id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Profiles.set_primary_photo(user_id, photo_id) do
      :ok -> json(conn, %{message: "primary_photo_set"})
      {:error, reason} -> {:error, reason}
    end
  end

  # POST /api/v1/profile/tags - Add tags
  def add_tags(conn, %{"tags" => tags}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    with {:ok, updated_tags} <- Profiles.add_tags(user_id, tags) do
      json(conn, %{tags: updated_tags})
    end
  end

  # DELETE /api/v1/profile/tags - Remove tag
  def remove_tag(conn, %{"category" => category, "value" => value}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    tag = %{"category" => category, "value" => value}

    case Profiles.remove_tag(user_id, tag) do
      :ok -> json(conn, %{message: "tag_removed"})
      {:error, reason} -> {:error, reason}
    end
  end

  # GET /api/v1/tags - Tags catalog (public)
  def tags_catalog(conn, params) do
    tags = Profiles.get_tags_catalog(params)
    json(conn, %{tags: tags})
  end

  # --- Serialization ---

  defp serialize_profile(nil), do: nil

  defp serialize_profile(profile) do
    profile
    |> Map.drop(["_id"])
    |> Map.update("user_id", nil, &to_string/1)
  end
end
