defmodule KoikoiWeb.MatchingController do
  use KoikoiWeb, :controller

  alias Koikoi.Matching

  action_fallback KoikoiWeb.FallbackController

  # GET /api/v1/matching/cards
  def deal_cards(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    matchmaker_id = to_string(current_user["_id"])

    with {:ok, pairs} <- Matching.deal_cards(matchmaker_id) do
      json(conn, %{pairs: Enum.map(pairs, &serialize_pair/1)})
    end
  end

  # POST /api/v1/matching/rate
  def submit_rating(conn, params) do
    current_user = Guardian.Plug.current_resource(conn)
    matchmaker_id = to_string(current_user["_id"])

    with {:ok, result} <-
           Matching.submit_rating(
             matchmaker_id,
             params["person_a_id"],
             params["person_b_id"],
             params
           ) do
      match_info = format_match_result(result.match_result)

      conn
      |> put_status(:created)
      |> json(%{
        session: serialize_session(result.session),
        match_result: match_info
      })
    end
  end

  # POST /api/v1/matching/skip
  def skip_pair(conn, %{"person_a_id" => person_a_id, "person_b_id" => person_b_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    matchmaker_id = to_string(current_user["_id"])

    case Matching.skip_pair(matchmaker_id, person_a_id, person_b_id) do
      :ok ->
        json(conn, %{message: "pair_skipped"})

      {:error, reason} ->
        {:error, reason}
    end
  end

  # GET /api/v1/matches
  def list_matches(conn, params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    opts = [
      status: params["status"],
      page: parse_int(params["page"], 1),
      limit: parse_int(params["limit"], 20)
    ]

    with {:ok, matches} <- Matching.list_matches(user_id, opts) do
      json(conn, %{matches: Enum.map(matches, &serialize_match/1)})
    end
  end

  # GET /api/v1/matches/:match_id
  def get_match(conn, %{"match_id" => match_id}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, match} <- Matching.get_match(match_id, user_id) do
      json(conn, %{match: serialize_match(match)})
    end
  end

  # POST /api/v1/matches/:match_id/respond
  def respond_to_match(conn, %{"match_id" => match_id, "response" => response}) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, match} <- Matching.respond_to_match(match_id, user_id, response) do
      json(conn, %{match: serialize_match(match)})
    end
  end

  # GET /api/v1/matching/stats
  def matchmaker_stats(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    matchmaker_id = to_string(current_user["_id"])

    with {:ok, stats} <- Matching.get_matchmaker_stats(matchmaker_id) do
      json(conn, %{stats: stats})
    end
  end

  # --- Private Helpers ---

  defp serialize_pair(pair) do
    %{
      person_a: pair.person_a,
      person_b: pair.person_b,
      shared_tags: pair.shared_tags,
      priority_score: pair.priority_score
    }
  end

  defp serialize_session(session) do
    %{
      id: to_string(session["_id"]),
      matchmaker_id: maybe_to_string(session["matchmaker_id"]),
      person_a_id: maybe_to_string(session["person_a_id"]),
      person_b_id: maybe_to_string(session["person_b_id"]),
      rating: session["rating"],
      confidence: session["confidence"],
      signals: session["signals"],
      is_ai: session["is_ai"],
      skipped: session["skipped"],
      inserted_at: session["inserted_at"],
      updated_at: session["updated_at"]
    }
  end

  defp serialize_match(match) do
    %{
      id: to_string(match["_id"]),
      person_a_id: maybe_to_string(match["person_a_id"]),
      person_b_id: maybe_to_string(match["person_b_id"]),
      status: match["status"],
      compatibility_score: match["compatibility_score"],
      total_ratings: match["total_ratings"],
      match_type: match["match_type"],
      signal_summary: match["signal_summary"],
      person_a_response: match["person_a_response"],
      person_b_response: match["person_b_response"],
      conversation_id: maybe_to_string(match["conversation_id"]),
      expires_at: match["expires_at"],
      inserted_at: match["inserted_at"],
      updated_at: match["updated_at"]
    }
  end

  defp format_match_result({:ok, :already_matched}), do: %{status: "already_matched"}
  defp format_match_result({:ok, :below_threshold}), do: %{status: "below_threshold"}

  defp format_match_result({:ok, {:match_created, match}}),
    do: %{status: "match_created", match: serialize_match(match)}

  defp format_match_result(_), do: %{status: "unknown"}

  defp maybe_to_string(nil), do: nil
  defp maybe_to_string(val), do: to_string(val)

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> max(int, 1)
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: max(val, 1)
  defp parse_int(_, default), do: default
end
