defmodule Koikoi.AccountHelpers do
  @moduledoc """
  Helper functions for account-related tests.
  """

  alias Koikoi.Accounts

  @valid_user_attrs %{
    "phone_number" => "+81901234567",
    "password" => "password123",
    "gender" => "female",
    "date_of_birth" => "1995-03-15"
  }

  def valid_user_attrs(overrides \\ %{}) do
    Map.merge(@valid_user_attrs, overrides)
  end

  def create_test_user(overrides \\ %{}) do
    attrs = valid_user_attrs(overrides)
    {:ok, user} = Accounts.register_user(attrs)
    user
  end

  def create_test_user_with_tokens(overrides \\ %{}) do
    user = create_test_user(overrides)
    {:ok, access_token, refresh_token} = Accounts.create_tokens(user)
    {user, access_token, refresh_token}
  end

  def authenticated_conn(conn, access_token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{access_token}")
  end
end
