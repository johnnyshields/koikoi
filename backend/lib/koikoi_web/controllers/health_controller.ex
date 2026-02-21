defmodule KoikoiWeb.HealthController do
  use KoikoiWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", app: "koikoi", version: "0.1.0"})
  end
end
