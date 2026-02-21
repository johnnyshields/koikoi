defmodule Koikoi.Seeds.TestUsers do
  @moduledoc """
  Seeds test users with realistic Japanese profile data.
  Run with: mix run -e "Koikoi.Seeds.TestUsers.run()"
  """

  require Logger

  alias Koikoi.Accounts

  @password "password123"

  def run do
    Logger.info("Seeding test users...")
    Mongo.delete_many(:mongo, "users", %{})
    Mongo.delete_many(:mongo, "profiles", %{})

    users = test_users()
    profiles = test_profiles()

    Enum.each(users, fn user_attrs ->
      case Accounts.register_user(user_attrs) do
        {:ok, user} ->
          Logger.info("Created user: #{user["phone_number"]}")

          # Find matching profile data
          profile_data =
            Enum.find(profiles, fn p -> p.phone_number == user_attrs["phone_number"] end)

          if profile_data do
            profile = build_profile(user, profile_data)
            {:ok, _} = Mongo.insert_one(:mongo, "profiles", profile)
            Logger.info("Created profile for: #{profile_data.display_name}")
          end

        {:error, reason} ->
          Logger.warning(
            "Failed to create user #{user_attrs["phone_number"]}: #{inspect(reason)}"
          )
      end
    end)

    {:ok, count} = Mongo.count_documents(:mongo, "users", %{})
    Logger.info("Seeded #{count} test users")
  end

  defp test_users do
    [
      %{
        "phone_number" => "+81901111001",
        "password" => @password,
        "gender" => "female",
        "date_of_birth" => "1995-03-15"
      },
      %{
        "phone_number" => "+81901111002",
        "password" => @password,
        "gender" => "female",
        "date_of_birth" => "1993-07-22"
      },
      %{
        "phone_number" => "+81901111003",
        "password" => @password,
        "gender" => "female",
        "date_of_birth" => "1997-11-08"
      },
      %{
        "phone_number" => "+81901111004",
        "password" => @password,
        "gender" => "female",
        "date_of_birth" => "1994-01-30"
      },
      %{
        "phone_number" => "+81901111005",
        "password" => @password,
        "gender" => "female",
        "date_of_birth" => "1996-09-12"
      },
      %{
        "phone_number" => "+81902222001",
        "password" => @password,
        "gender" => "male",
        "date_of_birth" => "1992-05-20"
      },
      %{
        "phone_number" => "+81902222002",
        "password" => @password,
        "gender" => "male",
        "date_of_birth" => "1994-12-03"
      },
      %{
        "phone_number" => "+81902222003",
        "password" => @password,
        "gender" => "male",
        "date_of_birth" => "1991-08-17"
      },
      %{
        "phone_number" => "+81902222004",
        "password" => @password,
        "gender" => "male",
        "date_of_birth" => "1996-02-28"
      },
      %{
        "phone_number" => "+81902222005",
        "password" => @password,
        "gender" => "male",
        "date_of_birth" => "1993-10-05"
      }
    ]
  end

  defp test_profiles do
    [
      %{
        phone_number: "+81901111001",
        display_name: "さくら",
        bio: "東京でデザイナーとして働いています。カフェ巡りと美術館が大好き。穏やかな人と出会いたいです。",
        occupation: "グラフィックデザイナー",
        location_name: "東京都渋谷区",
        location: %{type: "Point", coordinates: [139.7036, 35.6595]},
        height_cm: 158,
        tags: ["cafe_lover", "art", "photography", "yoga", "japanese_food"]
      },
      %{
        phone_number: "+81901111002",
        display_name: "あおい",
        bio: "大阪生まれ、大阪育ち。笑いの絶えない毎日を過ごしています。一緒に美味しいものを食べに行きましょう！",
        occupation: "看護師",
        location_name: "大阪府大阪市",
        location: %{type: "Point", coordinates: [135.5023, 34.6937]},
        height_cm: 162,
        tags: ["food_explorer", "hiking", "karaoke", "korean_food", "cheerful"]
      },
      %{
        phone_number: "+81901111003",
        display_name: "ひなた",
        bio: "エンジニアです。プログラミングも好きだけど、休日は山登りやキャンプを楽しんでいます。",
        occupation: "ソフトウェアエンジニア",
        location_name: "東京都世田谷区",
        location: %{type: "Point", coordinates: [139.6532, 35.6468]},
        height_cm: 165,
        tags: ["engineer", "hiking", "camping", "gaming", "technology"]
      },
      %{
        phone_number: "+81901111004",
        display_name: "まい",
        bio: "ピアノを弾くのが趣味です。クラシック音楽が好きで、コンサートによく行きます。落ち着いた方が好みです。",
        occupation: "ピアノ講師",
        location_name: "神奈川県横浜市",
        location: %{type: "Point", coordinates: [139.6380, 35.4437]},
        height_cm: 155,
        tags: ["piano", "classical", "live_concerts", "tea_ceremony", "calm"]
      },
      %{
        phone_number: "+81901111005",
        display_name: "りん",
        bio: "旅行が大好きで、年に3回は海外に行きます。新しい文化や食べ物を体験するのが楽しい！",
        occupation: "旅行代理店勤務",
        location_name: "東京都港区",
        location: %{type: "Point", coordinates: [139.7454, 35.6586]},
        height_cm: 160,
        tags: [
          "international_travel",
          "food_tourism",
          "photography",
          "learning_languages",
          "adventurous_spirit"
        ]
      },
      %{
        phone_number: "+81902222001",
        display_name: "たくや",
        bio: "IT企業で働いています。週末はジムで筋トレかランニング。料理も少しします。真剣に出会いを探しています。",
        occupation: "プロジェクトマネージャー",
        location_name: "東京都新宿区",
        location: %{type: "Point", coordinates: [139.7103, 35.6938]},
        height_cm: 175,
        tags: ["gym", "running", "home_cooking", "technology", "ambitious"]
      },
      %{
        phone_number: "+81902222002",
        display_name: "ゆうと",
        bio: "建築士です。美しいものが好きで、休日は美術館や建築巡りをしています。一緒にカフェでゆっくりしませんか。",
        occupation: "建築士",
        location_name: "東京都目黒区",
        location: %{type: "Point", coordinates: [139.6980, 35.6340]},
        height_cm: 178,
        tags: ["art", "cafe_lover", "photography", "city_exploration", "creative_mind"]
      },
      %{
        phone_number: "+81902222003",
        display_name: "けんじ",
        bio: "料理人です。和食をメインに作っています。食べることも作ることも大好き。お酒も少々。",
        occupation: "料理人",
        location_name: "京都府京都市",
        location: %{type: "Point", coordinates: [135.7681, 35.0116]},
        height_cm: 170,
        tags: ["japanese_food", "cooking", "sushi", "craft_beer", "shrine_temple"]
      },
      %{
        phone_number: "+81902222004",
        display_name: "そうた",
        bio: "スタートアップで働くエンジニア。サーフィンとキャンプが好き。自然の中でリフレッシュするのが好き。",
        occupation: "フルスタックエンジニア",
        location_name: "神奈川県藤沢市",
        location: %{type: "Point", coordinates: [139.4870, 35.3408]},
        height_cm: 180,
        tags: ["surfing", "camping", "startup", "engineer", "outdoor_lover"]
      },
      %{
        phone_number: "+81902222005",
        display_name: "はると",
        bio: "音楽プロデューサーとして活動中。ギターとピアノが弾けます。音楽好きな方と繋がりたいです。",
        occupation: "音楽プロデューサー",
        location_name: "東京都渋谷区",
        location: %{type: "Point", coordinates: [139.6917, 35.6647]},
        height_cm: 173,
        tags: ["instrument_player", "jpop", "live_concerts", "band_music", "creative_mind"]
      }
    ]
  end

  defp build_profile(user, profile_data) do
    now = DateTime.utc_now()

    %{
      user_id: to_string(user["_id"]),
      display_name: profile_data.display_name,
      bio: profile_data.bio,
      occupation: profile_data.occupation,
      location_name: profile_data.location_name,
      location: profile_data.location,
      height_cm: profile_data.height_cm,
      photo_urls: [],
      tag_ids: profile_data.tags,
      visibility: "visible",
      gender: user["gender"],
      age: calculate_age(user["date_of_birth"]),
      inserted_at: now,
      updated_at: now
    }
  end

  defp calculate_age(nil), do: nil

  defp calculate_age(dob) when is_binary(dob) do
    case Date.from_iso8601(dob) do
      {:ok, date} -> calculate_age(date)
      _ -> nil
    end
  end

  defp calculate_age(%Date{} = dob) do
    today = Date.utc_today()
    age = today.year - dob.year

    if Date.compare(Date.new!(today.year, dob.month, dob.day), today) == :gt do
      age - 1
    else
      age
    end
  end

  defp calculate_age(_), do: nil
end
