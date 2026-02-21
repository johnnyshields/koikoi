defmodule Koikoi.AiMatchmaker do
  @moduledoc """
  The AI Matchmaker context provides rule-based compatibility analysis
  and cold-start rating generation through the 恋のキューピッド (Love's Cupid) persona.
  """

  alias Koikoi.AiMatchmaker.{ProfileAnalyzer, Persona, ColdStartWorker}
  alias Koikoi.{Profiles, Accounts, Repo}

  @sessions_collection "matchmaking_sessions"

  @doc "Analyze compatibility between two users."
  def analyze_pair(user_a_id, user_b_id) do
    with {:ok, profile_a} <- Profiles.get_profile(user_a_id),
         {:ok, profile_b} <- Profiles.get_profile(user_b_id),
         user_a when not is_nil(user_a) <- Accounts.get_user(user_a_id),
         user_b when not is_nil(user_b) <- Accounts.get_user(user_b_id) do
      analysis = ProfileAnalyzer.analyze(profile_a, profile_b, user_a, user_b)
      note_ja = Persona.generate_note(analysis.reasons)
      note_en = Persona.generate_note_en(analysis.reasons)

      {:ok,
       Map.merge(analysis, %{
         note_ja: note_ja,
         note_en: note_en,
         persona: get_ai_persona()
       })}
    else
      {:error, _} = error -> error
      nil -> {:error, :not_found}
    end
  end

  @doc "Get the AI persona info."
  def get_ai_persona do
    %{
      id: Persona.id(),
      name_ja: Persona.name_ja(),
      name_en: Persona.name_en(),
      avatar_url: Persona.avatar_url()
    }
  end

  @doc "Get AI-generated ratings for a specific pair."
  def get_ai_ratings_for_pair(person_a_id, person_b_id) do
    {a_id, b_id} = canonical_pair(person_a_id, person_b_id)
    a_oid = to_oid(a_id)
    b_oid = to_oid(b_id)

    sessions =
      Repo.find(@sessions_collection, %{
        person_a_id: a_oid,
        person_b_id: b_oid,
        is_ai: true,
        skipped: false
      })
      |> Enum.to_list()

    {:ok, sessions}
  end

  @doc "Get all AI ratings involving a specific user."
  def get_ai_ratings_for_user(user_id) do
    user_oid = to_oid(user_id)

    sessions =
      Repo.find(
        @sessions_collection,
        %{
          "$or" => [
            %{person_a_id: user_oid},
            %{person_b_id: user_oid}
          ],
          is_ai: true,
          skipped: false
        },
        sort: %{inserted_at: -1},
        limit: 50
      )
      |> Enum.to_list()

    {:ok, sessions}
  end

  @doc "Manually trigger cold-start AI rating generation for a user."
  def trigger_cold_start_for_user(user_id) do
    ColdStartWorker.trigger_for_user(user_id)
    :ok
  end

  # --- Helpers ---

  defp canonical_pair(id_a, id_b) do
    a = to_string(id_a)
    b = to_string(id_b)
    if a < b, do: {a, b}, else: {b, a}
  end

  defp to_oid(id) when is_binary(id) do
    case BSON.ObjectId.decode(id) do
      {:ok, oid} -> oid
      :error -> id
    end
  end

  defp to_oid(%BSON.ObjectId{} = oid), do: oid
  defp to_oid(id), do: id
end
