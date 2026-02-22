defmodule KoikoiWeb.ShokaiController do
  use KoikoiWeb, :controller

  alias Koikoi.Shokai

  action_fallback KoikoiWeb.FallbackController

  # POST /api/v1/shokai
  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    opts = %{
      "note" => params["note"],
      "source_conversation_id" => params["source_conversation_id"]
    }

    case Shokai.create_shokai(user_id, params["person_a_id"], params["person_b_id"], opts) do
      {:ok, shokai} ->
        conn |> put_status(:created) |> json(%{shokai: serialize_shokai(shokai)})

      {:error, :not_friends_with_both} ->
        conn |> put_status(:forbidden) |> json(%{error: "not_friends_with_both"})

      {:error, :active_shokai_exists} ->
        conn |> put_status(:conflict) |> json(%{error: "active_shokai_exists"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # GET /api/v1/shokai/pending
  def pending(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    {:ok, shokais} = Shokai.list_pending(user_id)
    json(conn, %{shokais: Enum.map(shokais, &serialize_shokai/1)})
  end

  # GET /api/v1/shokai/sent
  def sent(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    {:ok, shokais} = Shokai.list_sent(user_id)
    json(conn, %{shokais: Enum.map(shokais, &serialize_shokai/1)})
  end

  # GET /api/v1/shokai/suggestions
  def suggestions(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Shokai.get_suggestions(user_id) do
      {:ok, suggestions} ->
        json(conn, %{suggestions: suggestions})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # GET /api/v1/shokai/:id
  def show(conn, %{"id" => id}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Shokai.get_shokai(id, user_id) do
      {:ok, shokai} ->
        json(conn, %{shokai: serialize_shokai(shokai)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, :unauthorized} ->
        conn |> put_status(:forbidden) |> json(%{error: "unauthorized"})
    end
  end

  # POST /api/v1/shokai/:id/respond
  def respond(conn, %{"id" => id, "response" => response}) do
    user = Guardian.Plug.current_resource(conn)
    user_id = to_string(user["_id"])

    case Shokai.respond_to_shokai(id, user_id, response) do
      {:ok, shokai} ->
        conv_id = maybe_to_string(shokai["result_conversation_id"])
        json(conn, %{shokai: serialize_shokai(shokai), conversation_id: conv_id})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, :not_pending} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "not_pending"})

      {:error, :unauthorized} ->
        conn |> put_status(:forbidden) |> json(%{error: "unauthorized"})

      {:error, reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: to_string(reason)})
    end
  end

  # --- Private ---

  defp serialize_shokai(shokai) do
    %{
      id: to_string(shokai["_id"]),
      matchmaker_id: to_string(shokai["matchmaker_id"]),
      person_a_id: to_string(shokai["person_a_id"]),
      person_b_id: to_string(shokai["person_b_id"]),
      person_a_response: shokai["person_a_response"],
      person_b_response: shokai["person_b_response"],
      matchmaker_note: shokai["matchmaker_note"],
      compatibility_hints: shokai["compatibility_hints"],
      status: shokai["status"],
      result_conversation_id: maybe_to_string(shokai["result_conversation_id"]),
      expires_at: shokai["expires_at"],
      inserted_at: shokai["inserted_at"],
      updated_at: shokai["updated_at"]
    }
  end

  defp maybe_to_string(nil), do: nil
  defp maybe_to_string(val), do: to_string(val)
end
