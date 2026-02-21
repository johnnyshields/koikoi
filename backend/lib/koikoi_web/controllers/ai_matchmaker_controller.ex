defmodule KoikoiWeb.AiMatchmakerController do
  use KoikoiWeb, :controller

  alias Koikoi.AiMatchmaker

  action_fallback KoikoiWeb.FallbackController

  # GET /api/v1/ai-matchmaker/persona
  def persona(conn, _params) do
    persona = AiMatchmaker.get_ai_persona()
    json(conn, %{persona: persona})
  end

  # GET /api/v1/ai-matchmaker/analysis/:user_a_id/:user_b_id
  def analyze(conn, %{"user_a_id" => user_a_id, "user_b_id" => user_b_id}) do
    with {:ok, analysis} <- AiMatchmaker.analyze_pair(user_a_id, user_b_id) do
      json(conn, %{
        analysis: %{
          score: analysis.score,
          confidence: analysis.confidence,
          reasons: Enum.map(analysis.reasons, &serialize_reason/1),
          note_ja: analysis.note_ja,
          note_en: analysis.note_en,
          persona: analysis.persona
        }
      })
    end
  end

  # POST /api/v1/ai-matchmaker/trigger
  def trigger_cold_start(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    :ok = AiMatchmaker.trigger_cold_start_for_user(user_id)

    json(conn, %{message: "ai_analysis_triggered"})
  end

  # GET /api/v1/ai-matchmaker/ratings
  def ai_ratings(conn, _params) do
    current_user = Guardian.Plug.current_resource(conn)
    user_id = to_string(current_user["_id"])

    with {:ok, sessions} <- AiMatchmaker.get_ai_ratings_for_user(user_id) do
      json(conn, %{
        ratings: Enum.map(sessions, &serialize_session/1),
        persona: AiMatchmaker.get_ai_persona()
      })
    end
  end

  # --- Private Helpers ---

  defp serialize_reason(reason) do
    %{
      type: reason.type,
      description_ja: reason.description_ja,
      description_en: reason.description_en,
      weight: reason.weight
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
      inserted_at: session["inserted_at"]
    }
  end

  defp maybe_to_string(nil), do: nil
  defp maybe_to_string(val), do: to_string(val)
end
