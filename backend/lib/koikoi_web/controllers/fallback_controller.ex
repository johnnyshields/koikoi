defmodule KoikoiWeb.FallbackController do
  use KoikoiWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found"})
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized"})
  end

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_credentials"})
  end

  def call(conn, {:error, :invalid_token}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_token"})
  end

  def call(conn, {:error, :subscription_required}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "subscription_required"})
  end

  def call(conn, {:error, :insufficient_credits}) do
    conn
    |> put_status(:payment_required)
    |> json(%{error: "insufficient_credits"})
  end

  def call(conn, {:error, :max_photos_reached}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "max_photos_reached"})
  end

  def call(conn, {:error, :phone_not_verified}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "phone_not_verified"})
  end

  def call(conn, {:error, :invalid_code}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "invalid_verification_code"})
  end

  def call(conn, {:error, :expired_code}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "verification_code_expired"})
  end

  def call(conn, {:error, changeset = %{}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_failed", details: changeset})
  end

  def call(conn, {:error, reason}) when is_binary(reason) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: reason})
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: to_string(reason)})
  end
end
