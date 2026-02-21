defmodule Koikoi.Seeds.TagsCatalog do
  @moduledoc """
  Seeds the tags_catalog collection with predefined Japanese tags.
  Run with: mix run -e "Koikoi.Seeds.TagsCatalog.run()"
  """

  require Logger

  def run do
    Logger.info("Seeding tags_catalog...")
    Mongo.delete_many(:mongo, "tags_catalog", %{})

    tags = build_all_tags()
    {:ok, result} = Mongo.insert_many(:mongo, "tags_catalog", tags)
    Logger.info("Inserted #{length(result.inserted_ids)} tags into tags_catalog")
  end

  defp build_all_tags do
    [
      interests_tags(),
      lifestyle_tags(),
      values_tags(),
      personality_tags(),
      food_tags(),
      music_tags(),
      sports_tags(),
      travel_tags(),
      hobbies_tags(),
      career_tags()
    ]
    |> List.flatten()
    |> Enum.with_index(1)
    |> Enum.map(fn {tag, idx} -> Map.put(tag, :sort_order, idx) end)
  end

  defp interests_tags do
    now = DateTime.utc_now()

    [
      {"reading", "読書", "📚"},
      {"movies", "映画鑑賞", "🎬"},
      {"anime", "アニメ", "🎌"},
      {"manga", "漫画", "📖"},
      {"gaming", "ゲーム", "🎮"},
      {"photography", "写真", "📷"},
      {"art", "アート・美術", "🎨"},
      {"music_listening", "音楽鑑賞", "🎵"},
      {"cooking", "料理", "🍳"},
      {"gardening", "ガーデニング", "🌱"},
      {"pets", "ペット", "🐾"},
      {"technology", "テクノロジー", "💻"},
      {"fashion", "ファッション", "👗"},
      {"beauty", "美容", "💄"},
      {"theater", "演劇・舞台", "🎭"},
      {"calligraphy", "書道", "✍️"},
      {"pottery", "陶芸", "🏺"},
      {"flower_arrangement", "華道", "💐"},
      {"tea_ceremony", "茶道", "🍵"},
      {"crafts", "手芸・ハンドメイド", "🧶"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "interests",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp lifestyle_tags do
    now = DateTime.utc_now()

    [
      {"early_riser", "朝型", "🌅"},
      {"night_owl", "夜型", "🌙"},
      {"outdoor_lover", "アウトドア派", "🏕️"},
      {"indoor_lover", "インドア派", "🏠"},
      {"fitness_enthusiast", "フィットネス好き", "💪"},
      {"health_conscious", "健康志向", "🥗"},
      {"social_drinker", "お酒たしなむ", "🍷"},
      {"non_drinker", "お酒飲まない", "🚫"},
      {"smoker", "喫煙者", "🚬"},
      {"non_smoker", "非喫煙者", "🚭"},
      {"minimalist", "ミニマリスト", "✨"},
      {"city_life", "都会派", "🏙️"},
      {"country_life", "田舎派", "🌾"},
      {"eco_friendly", "エコ志向", "♻️"},
      {"work_life_balance", "ワークライフバランス重視", "⚖️"},
      {"career_focused", "キャリア重視", "📈"},
      {"freelancer", "フリーランス", "💼"},
      {"remote_worker", "リモートワーク", "🏡"},
      {"plant_based", "ベジタリアン・ヴィーガン", "🥬"},
      {"car_enthusiast", "車好き", "🚗"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "lifestyle",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp values_tags do
    now = DateTime.utc_now()

    [
      {"family_oriented", "家族思い", "👨‍👩‍👧‍👦"},
      {"wants_children", "子供欲しい", "👶"},
      {"no_children", "子供はいらない", "🚫"},
      {"traditional", "伝統的", "🏯"},
      {"progressive", "革新的", "🌈"},
      {"religious", "信仰あり", "🙏"},
      {"spiritual", "スピリチュアル", "🧘"},
      {"honest", "誠実", "💎"},
      {"ambitious", "野心的", "🎯"},
      {"compassionate", "思いやりがある", "💕"},
      {"independent", "自立している", "🦅"},
      {"loyal", "一途", "🤝"},
      {"open_minded", "オープンマインド", "🌍"},
      {"respectful", "礼儀正しい", "🎩"},
      {"adventurous_spirit", "冒険心", "🧭"},
      {"patience", "忍耐力", "🧘‍♂️"},
      {"sense_of_humor", "ユーモアのセンス", "😄"},
      {"intellectual", "知的好奇心", "🧠"},
      {"creative_mind", "クリエイティブ", "🎪"},
      {"community_minded", "地域貢献", "🤲"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "values",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp personality_tags do
    now = DateTime.utc_now()

    [
      {"introvert", "内向的", "🤫"},
      {"extrovert", "外向的", "🎉"},
      {"ambivert", "両方", "🔄"},
      {"calm", "穏やか", "😌"},
      {"energetic", "エネルギッシュ", "⚡"},
      {"romantic", "ロマンチスト", "🌹"},
      {"practical", "現実的", "📊"},
      {"optimistic", "楽観的", "☀️"},
      {"empathetic", "共感力がある", "🫂"},
      {"decisive", "決断力がある", "⚔️"},
      {"laid_back", "おおらか", "🏖️"},
      {"organized", "几帳面", "📋"},
      {"spontaneous", "自由奔放", "🎲"},
      {"thoughtful", "思慮深い", "🤔"},
      {"cheerful", "明るい", "😊"},
      {"shy", "恥ずかしがり屋", "🙈"},
      {"confident", "自信がある", "💫"},
      {"caring", "面倒見が良い", "🤗"},
      {"funny", "面白い", "🤣"},
      {"serious", "真面目", "🧐"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "personality",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp food_tags do
    now = DateTime.utc_now()

    [
      {"japanese_food", "和食好き", "🍱"},
      {"italian_food", "イタリアン好き", "🍝"},
      {"french_food", "フレンチ好き", "🥐"},
      {"chinese_food", "中華好き", "🥟"},
      {"korean_food", "韓国料理好き", "🍜"},
      {"thai_food", "タイ料理好き", "🍛"},
      {"sweets", "甘いもの好き", "🍰"},
      {"ramen", "ラーメン好き", "🍜"},
      {"sushi", "寿司好き", "🍣"},
      {"cafe_lover", "カフェ巡り", "☕"},
      {"wine_lover", "ワイン好き", "🍷"},
      {"craft_beer", "クラフトビール", "🍺"},
      {"home_cooking", "自炊派", "🏠"},
      {"food_explorer", "食べ歩き", "🚶"},
      {"baking", "お菓子作り", "🧁"},
      {"spicy_food", "辛い物好き", "🌶️"},
      {"healthy_eating", "ヘルシー志向", "🥑"},
      {"bbq", "BBQ・焼肉", "🥩"},
      {"seafood", "海鮮好き", "🦐"},
      {"izakaya", "居酒屋好き", "🏮"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "food",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp music_tags do
    now = DateTime.utc_now()

    [
      {"jpop", "J-POP", "🎤"},
      {"kpop", "K-POP", "🎶"},
      {"rock", "ロック", "🎸"},
      {"classical", "クラシック", "🎻"},
      {"jazz", "ジャズ", "🎷"},
      {"hiphop", "ヒップホップ", "🎧"},
      {"edm", "EDM", "🎹"},
      {"r_and_b", "R&B", "🎙️"},
      {"folk", "フォーク・民謡", "🪕"},
      {"idol", "アイドル", "⭐"},
      {"vocaloid", "ボカロ", "🤖"},
      {"enka", "演歌", "🎌"},
      {"live_concerts", "ライブ・コンサート", "🎪"},
      {"karaoke", "カラオケ", "🎤"},
      {"instrument_player", "楽器演奏", "🎼"},
      {"band_music", "バンド", "🎸"},
      {"acoustic", "アコースティック", "🪗"},
      {"reggae", "レゲエ", "🌴"},
      {"metal", "メタル", "🤘"},
      {"city_pop", "シティポップ", "🌆"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "music",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp sports_tags do
    now = DateTime.utc_now()

    [
      {"running", "ランニング", "🏃"},
      {"yoga", "ヨガ", "🧘"},
      {"swimming", "水泳", "🏊"},
      {"tennis", "テニス", "🎾"},
      {"golf", "ゴルフ", "⛳"},
      {"soccer", "サッカー", "⚽"},
      {"baseball", "野球", "⚾"},
      {"basketball", "バスケットボール", "🏀"},
      {"volleyball", "バレーボール", "🏐"},
      {"skiing", "スキー・スノーボード", "⛷️"},
      {"surfing", "サーフィン", "🏄"},
      {"hiking", "ハイキング・登山", "🥾"},
      {"cycling", "サイクリング", "🚴"},
      {"martial_arts", "武道・格闘技", "🥋"},
      {"dance", "ダンス", "💃"},
      {"gym", "ジム・筋トレ", "🏋️"},
      {"badminton", "バドミントン", "🏸"},
      {"table_tennis", "卓球", "🏓"},
      {"climbing", "ボルダリング", "🧗"},
      {"boxing", "ボクシング", "🥊"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "sports",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp travel_tags do
    now = DateTime.utc_now()

    [
      {"domestic_travel", "国内旅行", "🗾"},
      {"international_travel", "海外旅行", "✈️"},
      {"onsen", "温泉巡り", "♨️"},
      {"camping", "キャンプ", "⛺"},
      {"backpacking", "バックパッカー", "🎒"},
      {"luxury_travel", "贅沢な旅行", "🏨"},
      {"road_trip", "ドライブ旅行", "🚗"},
      {"beach", "ビーチ・海", "🏖️"},
      {"mountain", "山・高原", "🏔️"},
      {"cultural_sites", "歴史・文化遺産巡り", "🏛️"},
      {"shrine_temple", "神社仏閣巡り", "⛩️"},
      {"festival", "お祭り好き", "🎆"},
      {"solo_travel", "一人旅", "🧳"},
      {"couple_travel", "二人旅", "👫"},
      {"group_travel", "グループ旅行", "👥"},
      {"island_hopping", "離島巡り", "🏝️"},
      {"train_travel", "鉄道旅行", "🚃"},
      {"food_tourism", "グルメ旅", "🍴"},
      {"nature", "自然・絶景", "🌿"},
      {"city_exploration", "街歩き", "🌃"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "travel",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp hobbies_tags do
    now = DateTime.utc_now()

    [
      {"board_games", "ボードゲーム", "🎲"},
      {"puzzles", "パズル", "🧩"},
      {"diy", "DIY", "🔨"},
      {"fishing", "釣り", "🎣"},
      {"astronomy", "天体観測", "🔭"},
      {"bird_watching", "バードウォッチング", "🐦"},
      {"collecting", "コレクション", "🗂️"},
      {"cosplay", "コスプレ", "🎭"},
      {"volunteering", "ボランティア", "🤝"},
      {"learning_languages", "語学学習", "🗣️"},
      {"meditation", "瞑想", "🧘‍♀️"},
      {"journaling", "日記・手帳", "📓"},
      {"video_creation", "動画制作", "📹"},
      {"podcasting", "ポッドキャスト", "🎙️"},
      {"wine_tasting", "ワインテイスティング", "🍇"},
      {"aquarium", "アクアリウム", "🐠"},
      {"origami", "折り紙", "🦢"},
      {"piano", "ピアノ", "🎹"},
      {"singing", "歌", "🎤"},
      {"magic_tricks", "マジック", "🪄"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "hobbies",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp career_tags do
    now = DateTime.utc_now()

    [
      {"engineer", "エンジニア", "👨‍💻"},
      {"designer", "デザイナー", "🎨"},
      {"teacher", "教師・講師", "👨‍🏫"},
      {"medical", "医療関係", "🏥"},
      {"finance", "金融・経理", "💰"},
      {"marketing", "マーケティング", "📣"},
      {"sales", "営業", "🤝"},
      {"legal", "法律関係", "⚖️"},
      {"government", "公務員", "🏛️"},
      {"startup", "スタートアップ", "🚀"},
      {"creative", "クリエイティブ職", "✏️"},
      {"hospitality", "ホスピタリティ", "🛎️"},
      {"research", "研究職", "🔬"},
      {"consulting", "コンサルティング", "📊"},
      {"media", "メディア・出版", "📰"},
      {"real_estate", "不動産", "🏠"},
      {"agriculture", "農業", "🌾"},
      {"manufacturing", "製造業", "🏭"},
      {"ngo_npo", "NGO・NPO", "🌍"},
      {"entrepreneur", "起業家", "💡"}
    ]
    |> Enum.map(fn {slug, label_ja, emoji} ->
      %{
        category: "career",
        slug: slug,
        label: %{ja: label_ja, en: slug_to_english(slug)},
        emoji: emoji,
        inserted_at: now
      }
    end)
  end

  defp slug_to_english(slug) do
    slug
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
