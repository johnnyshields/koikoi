defmodule KoikoiWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint KoikoiWeb.Endpoint

      use KoikoiWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import KoikoiWeb.ConnCase
    end
  end

  setup tags do
    if tags[:mongodb] do
      # Clean up test collections before each MongoDB test
      Koikoi.Repo.delete_many("users", %{})
      Koikoi.Repo.delete_many("phone_verifications", %{})
      Koikoi.Repo.delete_many("profiles", %{})
      Koikoi.Repo.delete_many("tags_catalog", %{})
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
