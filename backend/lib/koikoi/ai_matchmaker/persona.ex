defmodule Koikoi.AiMatchmaker.Persona do
  @moduledoc "AI matchmaker persona - 恋のキューピッド (Love's Cupid)"

  @ai_matchmaker_id "ai_cupid"

  def id, do: @ai_matchmaker_id

  def name_ja, do: "恋のキューピッド"
  def name_en, do: "Love's Cupid"

  def avatar_url, do: "/images/ai_cupid_avatar.png"

  @doc "Generate a Japanese matchmaker note from analysis reasons."
  def generate_note(reasons) do
    reason_texts = Enum.map(reasons, & &1.description_ja)

    case reason_texts do
      [r1, r2 | _] ->
        Enum.random([
          "#{r1}し、#{r2}。きっと気が合うと思います！",
          "#{r1}✨ さらに#{r2}。素敵なペアです！"
        ])

      [r1] ->
        Enum.random([
          "この二人、#{r1}！素敵な出会いになりそうです✨",
          "キューピッドの直感です💕 #{r1}。"
        ])

      [] ->
        "プロフィールを見て、相性が良さそうだと感じました！"
    end
  end

  @doc "Generate an English matchmaker note from analysis reasons."
  def generate_note_en(reasons) do
    reason_texts = Enum.map(reasons, & &1.description_en)

    case reason_texts do
      [r1, r2 | _] ->
        "#{r1} and #{r2}. I think they'd get along great!"

      [r1] ->
        "Cupid's intuition! #{r1}."

      [] ->
        "Based on their profiles, they seem like a great match!"
    end
  end
end
