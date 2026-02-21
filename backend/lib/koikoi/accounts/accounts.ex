defmodule Koikoi.Accounts do
  @moduledoc """
  The Accounts context handles user registration, authentication,
  phone verification, and token management.
  """

  alias Koikoi.Repo
  alias Koikoi.Accounts.Guardian

  @users_collection "users"
  @phone_verifications_collection "phone_verifications"
  @verification_code_ttl_seconds 600

  # --- User CRUD ---

  def get_user(id) do
    oid = to_object_id(id)
    Repo.find_one(@users_collection, %{_id: oid})
  end

  def get_user_by_phone(phone_number) do
    Repo.find_one(@users_collection, %{phone_number: phone_number})
  end

  # --- Registration ---

  def register_user(attrs) do
    with :ok <- validate_registration(attrs),
         nil <- get_user_by_phone(attrs["phone_number"]) do
      now = DateTime.utc_now()

      document = %{
        phone_number: attrs["phone_number"],
        password_hash: Argon2.hash_pwd_salt(attrs["password"]),
        gender: attrs["gender"],
        date_of_birth: parse_date(attrs["date_of_birth"]),
        age_verified: false,
        phone_verified: false,
        subscription: %{plan: "free", expires_at: nil},
        credits: 0,
        matchmaker_settings: %{who_can_matchmake: "inner_circle"},
        invite_code: generate_invite_code(),
        matchmaker_invites_sent: 0,
        refresh_tokens: [],
        inserted_at: now,
        updated_at: now
      }

      case Repo.insert_one(@users_collection, document) do
        {:ok, result} ->
          user = Repo.find_one(@users_collection, %{_id: result.inserted_id})
          {:ok, user}

        {:error, reason} ->
          {:error, reason}
      end
    else
      %{} = _existing_user ->
        {:error, "phone_number_taken"}

      {:error, _} = error ->
        error
    end
  end

  defp validate_registration(attrs) do
    cond do
      blank?(attrs["phone_number"]) -> {:error, "phone_number_required"}
      blank?(attrs["password"]) -> {:error, "password_required"}
      String.length(attrs["password"] || "") < 8 -> {:error, "password_too_short"}
      blank?(attrs["gender"]) -> {:error, "gender_required"}
      attrs["gender"] not in ["male", "female", "other"] -> {:error, "invalid_gender"}
      blank?(attrs["date_of_birth"]) -> {:error, "date_of_birth_required"}
      true -> :ok
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> date_string
    end
  end

  defp parse_date(date), do: date

  # --- Authentication ---

  def authenticate(phone_number, password) do
    case get_user_by_phone(phone_number) do
      nil ->
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if Argon2.verify_pass(password, user["password_hash"]) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  # --- Token Management ---

  def create_tokens(user) do
    user_resource = %{id: to_string(user["_id"])}

    with {:ok, access_token, _claims} <-
           Guardian.encode_and_sign(user_resource, %{}, token_type: "access", ttl: {15, :minute}),
         {:ok, refresh_token, _claims} <-
           Guardian.encode_and_sign(user_resource, %{}, token_type: "refresh", ttl: {30, :day}) do
      refresh_hash = hash_token(refresh_token)
      expires_at = DateTime.add(DateTime.utc_now(), 30 * 24 * 3600, :second)

      Repo.update_one(
        @users_collection,
        %{_id: user["_id"]},
        %{
          "$push" => %{
            refresh_tokens: %{token_hash: refresh_hash, expires_at: expires_at}
          },
          "$set" => %{updated_at: DateTime.utc_now()}
        }
      )

      {:ok, access_token, refresh_token}
    end
  end

  def refresh_tokens(refresh_token) do
    with {:ok, claims} <- Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      refresh_hash = hash_token(refresh_token)

      # Verify the refresh token exists in user's stored tokens
      stored_token =
        Enum.find(user["refresh_tokens"] || [], fn rt ->
          rt["token_hash"] == refresh_hash
        end)

      if stored_token do
        # Remove old refresh token
        Repo.update_one(
          @users_collection,
          %{_id: user["_id"]},
          %{
            "$pull" => %{refresh_tokens: %{token_hash: refresh_hash}},
            "$set" => %{updated_at: DateTime.utc_now()}
          }
        )

        # Create new token pair
        create_tokens(user)
      else
        {:error, :invalid_token}
      end
    else
      {:error, _reason} -> {:error, :invalid_token}
    end
  end

  def revoke_token(refresh_token) do
    with {:ok, claims} <- Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}),
         {:ok, user} <- Guardian.resource_from_claims(claims) do
      refresh_hash = hash_token(refresh_token)

      Repo.update_one(
        @users_collection,
        %{_id: user["_id"]},
        %{
          "$pull" => %{refresh_tokens: %{token_hash: refresh_hash}},
          "$set" => %{updated_at: DateTime.utc_now()}
        }
      )

      :ok
    else
      _ -> :ok
    end
  end

  defp hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)
  end

  # --- Phone Verification ---

  def request_verification_code(phone_number) do
    code = generate_verification_code()
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, @verification_code_ttl_seconds, :second)

    # Upsert verification record
    Repo.delete_many(@phone_verifications_collection, %{phone_number: phone_number})

    Repo.insert_one(@phone_verifications_collection, %{
      phone_number: phone_number,
      code: code,
      expires_at: expires_at,
      verified: false,
      inserted_at: now
    })

    # In production, send SMS here. For now, log the code.
    require Logger
    Logger.info("Verification code for #{phone_number}: #{code}")

    {:ok, code}
  end

  def verify_phone(phone_number, code) do
    now = DateTime.utc_now()

    case Repo.find_one(@phone_verifications_collection, %{
           phone_number: phone_number,
           code: code
         }) do
      nil ->
        {:error, :invalid_code}

      verification ->
        if DateTime.compare(verification["expires_at"], now) == :gt do
          # Mark phone as verified on the user
          Repo.update_one(
            @users_collection,
            %{phone_number: phone_number},
            %{"$set" => %{phone_verified: true, updated_at: now}}
          )

          # Clean up verification record
          Repo.delete_many(@phone_verifications_collection, %{phone_number: phone_number})

          {:ok, true}
        else
          {:error, :expired_code}
        end
    end
  end

  # --- Helpers ---

  defp generate_invite_code do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper)
  end

  defp generate_verification_code do
    (:rand.uniform(899_999) + 100_000) |> Integer.to_string()
  end

  defp to_object_id(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, oid} -> oid
      :error -> id
    end
  end

  defp to_object_id(id), do: id
end
