defmodule Koikoi.AccountsTest do
  use ExUnit.Case, async: false

  import Koikoi.AccountHelpers

  alias Koikoi.Accounts

  @moduletag :mongodb

  setup do
    Koikoi.Repo.delete_many("users", %{})
    Koikoi.Repo.delete_many("phone_verifications", %{})
    :ok
  end

  describe "register_user/1" do
    test "creates user with valid attributes" do
      attrs = valid_user_attrs()
      assert {:ok, user} = Accounts.register_user(attrs)
      assert user["phone_number"] == attrs["phone_number"]
      assert user["gender"] == "female"
      assert user["phone_verified"] == false
      assert user["age_verified"] == false
      assert user["credits"] == 0
      assert user["subscription"]["plan"] == "free"
      assert is_binary(user["invite_code"])
      assert String.length(user["invite_code"]) == 8
      assert user["password_hash"] != attrs["password"]
    end

    test "rejects duplicate phone number" do
      attrs = valid_user_attrs()
      assert {:ok, _user} = Accounts.register_user(attrs)
      assert {:error, "phone_number_taken"} = Accounts.register_user(attrs)
    end

    test "rejects missing phone number" do
      attrs = valid_user_attrs(%{"phone_number" => ""})
      assert {:error, "phone_number_required"} = Accounts.register_user(attrs)
    end

    test "rejects short password" do
      attrs = valid_user_attrs(%{"password" => "short"})
      assert {:error, "password_too_short"} = Accounts.register_user(attrs)
    end

    test "rejects invalid gender" do
      attrs = valid_user_attrs(%{"gender" => "invalid"})
      assert {:error, "invalid_gender"} = Accounts.register_user(attrs)
    end
  end

  describe "authenticate/2" do
    test "returns user with correct credentials" do
      attrs = valid_user_attrs()
      {:ok, _user} = Accounts.register_user(attrs)

      assert {:ok, user} = Accounts.authenticate(attrs["phone_number"], attrs["password"])
      assert user["phone_number"] == attrs["phone_number"]
    end

    test "returns error with wrong password" do
      attrs = valid_user_attrs()
      {:ok, _user} = Accounts.register_user(attrs)

      assert {:error, :invalid_credentials} =
               Accounts.authenticate(attrs["phone_number"], "wrong_password")
    end

    test "returns error for non-existent user" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate("+81900000000", "password123")
    end
  end

  describe "create_tokens/1 and refresh_tokens/1" do
    test "generates access and refresh tokens" do
      user = create_test_user()
      assert {:ok, access_token, refresh_token} = Accounts.create_tokens(user)
      assert is_binary(access_token)
      assert is_binary(refresh_token)
    end

    test "refresh tokens returns new token pair" do
      {_user, _access_token, refresh_token} = create_test_user_with_tokens()

      assert {:ok, new_access, new_refresh} = Accounts.refresh_tokens(refresh_token)
      assert is_binary(new_access)
      assert is_binary(new_refresh)
      assert new_refresh != refresh_token
    end

    test "refresh token cannot be reused after rotation" do
      {_user, _access_token, refresh_token} = create_test_user_with_tokens()

      # First refresh succeeds
      assert {:ok, _new_access, _new_refresh} = Accounts.refresh_tokens(refresh_token)

      # Second use of the same refresh token fails
      assert {:error, :invalid_token} = Accounts.refresh_tokens(refresh_token)
    end
  end

  describe "phone verification" do
    test "request_verification_code/1 generates a code" do
      phone = "+81901234567"
      assert {:ok, code} = Accounts.request_verification_code(phone)
      assert is_binary(code)
      assert String.length(code) == 6
    end

    test "verify_phone/2 verifies correct code" do
      attrs = valid_user_attrs()
      {:ok, _user} = Accounts.register_user(attrs)

      {:ok, code} = Accounts.request_verification_code(attrs["phone_number"])
      assert {:ok, true} = Accounts.verify_phone(attrs["phone_number"], code)

      # Confirm user is now phone_verified
      updated_user = Accounts.get_user_by_phone(attrs["phone_number"])
      assert updated_user["phone_verified"] == true
    end

    test "verify_phone/2 rejects invalid code" do
      phone = "+81901234567"
      {:ok, _code} = Accounts.request_verification_code(phone)

      assert {:error, :invalid_code} = Accounts.verify_phone(phone, "000000")
    end
  end
end
