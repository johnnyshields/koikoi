defmodule KoikoiWeb.AuthController do
  use KoikoiWeb, :controller

  alias Koikoi.Accounts

  action_fallback KoikoiWeb.FallbackController

  def register(conn, params) do
    with {:ok, user} <- Accounts.register_user(params),
         {:ok, access_token, refresh_token} <- Accounts.create_tokens(user) do
      conn
      |> put_status(:created)
      |> json(%{
        user: sanitize_user(user),
        access_token: access_token,
        refresh_token: refresh_token
      })
    end
  end

  def login(conn, %{"phone_number" => phone_number, "password" => password}) do
    with {:ok, user} <- Accounts.authenticate(phone_number, password),
         {:ok, access_token, refresh_token} <- Accounts.create_tokens(user) do
      json(conn, %{
        user: sanitize_user(user),
        access_token: access_token,
        refresh_token: refresh_token
      })
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    with {:ok, access_token, new_refresh_token} <- Accounts.refresh_tokens(refresh_token) do
      json(conn, %{
        access_token: access_token,
        refresh_token: new_refresh_token
      })
    end
  end

  def request_verification_code(conn, %{"phone_number" => phone_number}) do
    {:ok, _code} = Accounts.request_verification_code(phone_number)
    json(conn, %{message: "verification_code_sent"})
  end

  def verify_phone(conn, %{"phone_number" => phone_number, "code" => code}) do
    with {:ok, true} <- Accounts.verify_phone(phone_number, code) do
      json(conn, %{verified: true})
    end
  end

  def me(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    json(conn, %{user: sanitize_user(user)})
  end

  def logout(conn, %{"refresh_token" => refresh_token}) do
    Accounts.revoke_token(refresh_token)
    json(conn, %{message: "logged_out"})
  end

  def logout(conn, _params) do
    json(conn, %{message: "logged_out"})
  end

  defp sanitize_user(nil), do: nil

  defp sanitize_user(user) do
    %{
      id: to_string(user["_id"]),
      phone_number: user["phone_number"],
      gender: user["gender"],
      date_of_birth: user["date_of_birth"],
      age_verified: user["age_verified"],
      phone_verified: user["phone_verified"],
      subscription: user["subscription"],
      credits: user["credits"],
      invite_code: user["invite_code"],
      inserted_at: user["inserted_at"],
      updated_at: user["updated_at"]
    }
  end
end
