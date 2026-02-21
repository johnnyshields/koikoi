defmodule KoikoiWeb.AuthControllerTest do
  use KoikoiWeb.ConnCase, async: false

  import Koikoi.AccountHelpers

  @moduletag :mongodb

  setup do
    Koikoi.Repo.delete_many("users", %{})
    Koikoi.Repo.delete_many("phone_verifications", %{})
    :ok
  end

  describe "POST /api/v1/auth/register" do
    test "registers user with valid params", %{conn: conn} do
      attrs = valid_user_attrs()

      conn = post(conn, "/api/v1/auth/register", attrs)
      response = json_response(conn, 201)

      assert response["user"]["phone_number"] == attrs["phone_number"]
      assert response["user"]["gender"] == "female"
      assert is_binary(response["access_token"])
      assert is_binary(response["refresh_token"])
      refute Map.has_key?(response["user"], "password_hash")
    end

    test "returns error for duplicate phone", %{conn: conn} do
      attrs = valid_user_attrs()
      post(conn, "/api/v1/auth/register", attrs)

      conn = post(build_conn(), "/api/v1/auth/register", attrs)
      response = json_response(conn, 422)

      assert response["error"] == "phone_number_taken"
    end

    test "returns error for missing fields", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/register", %{})
      response = json_response(conn, 422)

      assert response["error"] == "phone_number_required"
    end
  end

  describe "POST /api/v1/auth/login" do
    test "logs in with valid credentials", %{conn: conn} do
      attrs = valid_user_attrs()
      create_test_user()

      conn =
        post(conn, "/api/v1/auth/login", %{
          phone_number: attrs["phone_number"],
          password: attrs["password"]
        })

      response = json_response(conn, 200)

      assert response["user"]["phone_number"] == attrs["phone_number"]
      assert is_binary(response["access_token"])
      assert is_binary(response["refresh_token"])
    end

    test "returns error for wrong password", %{conn: conn} do
      attrs = valid_user_attrs()
      create_test_user()

      conn =
        post(conn, "/api/v1/auth/login", %{
          phone_number: attrs["phone_number"],
          password: "wrong_password"
        })

      response = json_response(conn, 401)
      assert response["error"] == "invalid_credentials"
    end
  end

  describe "GET /api/v1/auth/me" do
    test "returns current user when authenticated", %{conn: conn} do
      {_user, access_token, _refresh} = create_test_user_with_tokens()

      conn =
        conn
        |> authenticated_conn(access_token)
        |> get("/api/v1/auth/me")

      response = json_response(conn, 200)
      assert response["user"]["phone_number"] == "+81901234567"
    end

    test "returns 401 when not authenticated", %{conn: conn} do
      conn = get(conn, "/api/v1/auth/me")
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/v1/auth/refresh" do
    test "refreshes tokens", %{conn: conn} do
      {_user, _access, refresh_token} = create_test_user_with_tokens()

      conn = post(conn, "/api/v1/auth/refresh", %{refresh_token: refresh_token})
      response = json_response(conn, 200)

      assert is_binary(response["access_token"])
      assert is_binary(response["refresh_token"])
      assert response["refresh_token"] != refresh_token
    end

    test "returns error for invalid refresh token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/refresh", %{refresh_token: "invalid"})
      response = json_response(conn, 401)

      assert response["error"] == "invalid_token"
    end
  end

  describe "POST /api/v1/auth/logout" do
    test "logs out and revokes token", %{conn: conn} do
      {_user, access_token, refresh_token} = create_test_user_with_tokens()

      conn =
        conn
        |> authenticated_conn(access_token)
        |> post("/api/v1/auth/logout", %{refresh_token: refresh_token})

      response = json_response(conn, 200)
      assert response["message"] == "logged_out"
    end
  end

  describe "GET /api/health" do
    test "returns health status", %{conn: conn} do
      conn = get(conn, "/api/health")
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["app"] == "koikoi"
    end
  end
end
