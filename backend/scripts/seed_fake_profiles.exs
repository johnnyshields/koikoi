defmodule Koikoi.FakeSeeder do
  @moduledoc """
  Seeds ~2000 fake users with profiles and a social graph centered on "me" (test user +81901111001 / さくら).

  Run with: cd backend && mix run scripts/seed_fake_profiles.exs
  """

  require Logger

  @fake_phone_prefix "+81903"
  @user_count 2000
  @batch_size 500
  @password "password123"

  # ── Data Pools ──────────────────────────────────────────────────────

  @female_names ~w(
    あかり あかね あい あおい あさひ あやか あやの あゆみ ちひろ えみ
    えりか はるか はるな ひかり ひな ひなた ほのか かえで かなえ かおり
    かりん きょうか こころ ことね まどか まい まき まこ まなみ まりこ
    みき みさき みゆ みゆき みづき もえ もも なな なつき なつみ
    のぞみ りえ りこ りな りの りさ るい さき さくらこ さやか
    しおり しずく そら すずか たまき ともか つばさ つむぎ わかな ゆい
    ゆうか ゆうな ゆき ゆきの ゆめ ゆりか まほ みお みれい ななみ
    れいか れいな れな りりか さえ さら しずか すみれ ちなつ ともみ
  )

  @male_names ~w(
    あきら あおと だいき だいすけ えいた はやと ひろき ひろと いつき じゅん
    かいと かずき けいすけ けんた こうき こうた こうへい まさと みなと なおき
    りく りょう りょうた りゅうせい しょう しゅん そうた たいが たいき たけし
    たくみ たつや ともや つばさ やまと ゆうき ゆうた ゆうと よしき あつし
    ふみや ごう はるき はると いさむ じろう かずや けんいち こうじ まこと
    まさき まさひろ のぶひろ おさむ れん りょうへい さとし しんじ しんや しゅうと
    しゅんすけ たかひろ たかし てつや とおる つよし わたる よしひろ ゆうすけ ゆうや
    あきと かいせい こうせい みつき るい しょうま そうすけ ゆうま ゆうせい ぜん
  )

  @prefectures [
    {"東京都", "東京", 0.20, [139.6917, 35.6895]},
    {"大阪府", "大阪市", 0.10, [135.5023, 34.6937]},
    {"神奈川県", "横浜市", 0.08, [139.6380, 35.4437]},
    {"愛知県", "名古屋市", 0.06, [136.9066, 35.1815]},
    {"埼玉県", "さいたま市", 0.05, [139.6489, 35.8617]},
    {"千葉県", "千葉市", 0.04, [140.1233, 35.6047]},
    {"兵庫県", "神戸市", 0.04, [135.1955, 34.6901]},
    {"北海道", "札幌市", 0.04, [141.3469, 43.0621]},
    {"福岡県", "福岡市", 0.04, [130.4017, 33.5904]},
    {"静岡県", "静岡市", 0.03, [138.3831, 34.9756]},
    {"茨城県", "水戸市", 0.02, [140.4468, 36.3415]},
    {"広島県", "広島市", 0.02, [132.4596, 34.3963]},
    {"京都府", "京都市", 0.03, [135.7681, 35.0116]},
    {"宮城県", "仙台市", 0.02, [140.8720, 38.2688]},
    {"新潟県", "新潟市", 0.01, [139.0236, 37.9026]},
    {"長野県", "長野市", 0.01, [138.1811, 36.6485]},
    {"岐阜県", "岐阜市", 0.01, [136.7614, 35.3912]},
    {"栃木県", "宇都宮市", 0.01, [139.8836, 36.5658]},
    {"群馬県", "前橋市", 0.01, [139.0609, 36.3911]},
    {"岡山県", "岡山市", 0.01, [133.9344, 34.6618]},
    {"三重県", "津市", 0.01, [136.5086, 34.7303]},
    {"熊本県", "熊本市", 0.01, [130.7417, 32.7898]},
    {"鹿児島県", "鹿児島市", 0.01, [130.5581, 31.5966]},
    {"沖縄県", "那覇市", 0.01, [127.6809, 26.2124]},
    {"滋賀県", "大津市", 0.01, [135.8685, 35.0045]},
    {"山口県", "山口市", 0.005, [131.4714, 34.1861]},
    {"愛媛県", "松山市", 0.005, [132.7657, 33.8416]},
    {"長崎県", "長崎市", 0.005, [129.8737, 32.7503]},
    {"奈良県", "奈良市", 0.01, [135.8048, 34.6851]},
    {"青森県", "青森市", 0.005, [140.7400, 40.8244]},
    {"岩手県", "盛岡市", 0.005, [141.1527, 39.7036]},
    {"大分県", "大分市", 0.005, [131.6126, 33.2382]},
    {"石川県", "金沢市", 0.005, [136.6256, 36.5944]},
    {"山形県", "山形市", 0.005, [140.3280, 38.2405]},
    {"宮崎県", "宮崎市", 0.005, [131.4239, 31.9111]},
    {"富山県", "富山市", 0.005, [137.2114, 36.6953]},
    {"秋田県", "秋田市", 0.005, [140.1023, 39.7186]},
    {"香川県", "高松市", 0.005, [134.0434, 34.3401]},
    {"和歌山県", "和歌山市", 0.005, [135.1675, 34.2260]},
    {"佐賀県", "佐賀市", 0.005, [130.2988, 33.2494]},
    {"山梨県", "甲府市", 0.005, [138.5688, 35.6642]},
    {"福井県", "福井市", 0.005, [136.2196, 36.0652]},
    {"徳島県", "徳島市", 0.005, [134.5593, 34.0658]},
    {"高知県", "高知市", 0.005, [133.5311, 33.5597]},
    {"島根県", "松江市", 0.005, [133.0505, 35.4723]},
    {"鳥取県", "鳥取市", 0.005, [134.2381, 35.5011]},
    {"福島県", "福島市", 0.01, [140.4677, 37.7500]}
  ]

  @occupations ~w(
    ソフトウェアエンジニア デザイナー 看護師 医師 薬剤師 弁護士 会計士
    営業職 マーケター コンサルタント 教師 公務員 銀行員 不動産営業
    料理人 美容師 カメラマン イラストレーター 建築士 歯科医師
    プロジェクトマネージャー データアナリスト 人事 経理 広報
    フリーランス 起業家 研究員 ライター 編集者
    インテリアデザイナー ウェブデザイナー 動画クリエイター
    理学療法士 介護福祉士 保育士 栄養士 トレーナー 通訳
    パイロット CA 旅行代理店勤務
  )

  @bio_templates [
    "__P__で__O__をしています。休日は__H__を楽しんでいます。素敵な出会いを探しています。",
    "__O__として働いています。__H__が好きで、一緒に楽しめる方と出会いたいです。",
    "__P__在住。__H__にハマっています。気軽にお話しましょう！",
    "__O__です。__H__が趣味で、同じ趣味の方と繋がりたいです。",
    "__P__で暮らしています。__H__と美味しいご飯が大好きです。",
    "__O__をしながら__H__を楽しむ日々。真剣に出会いを求めています。",
    "__P__出身です。__H__を通じて新しい出会いがあればと思っています。",
    "__H__好きの__O__です。一緒に楽しい時間を過ごせる方を探しています。",
    "普段は__O__として忙しくしていますが、休みの日は__H__でリフレッシュしています。",
    "__P__住み。仕事は__O__。趣味は__H__。よろしくお願いします！",
    "__O__をしています。__P__で一人暮らし中。__H__仲間募集中です。",
    "__H__と旅行が大好きです。__P__で__O__をしています。",
    "__P__の__O__です。週末は__H__をしていることが多いです。気軽にどうぞ。",
    "毎日__O__として頑張っています。__H__が癒し。__P__在住です。",
    "__H__が生きがいの__O__です。__P__で楽しく暮らしています。",
    "__O__歴5年。__P__で自分らしく生きています。__H__仲間歓迎です。",
    "__P__が大好きで離れられません。__O__の仕事も充実しています。",
    "のんびり__H__をする週末が幸せ。__P__の__O__です。",
    "__O__です。最近__H__を始めました。一緒に楽しみたいです。",
    "__H__をこよなく愛する__O__。__P__在住。お気軽にメッセージください。"
  ]

  @hobby_phrases [
    "カフェ巡り", "映画鑑賞", "読書", "ランニング", "ヨガ", "キャンプ",
    "料理", "旅行", "温泉巡り", "写真撮影", "美術館巡り", "音楽鑑賞",
    "ゲーム", "アニメ鑑賞", "サーフィン", "ハイキング", "スノーボード",
    "ダイビング", "ボルダリング", "ゴルフ", "テニス", "フットサル",
    "ガーデニング", "DIY", "陶芸", "書道"
  ]

  @body_types ~w(slim average athletic curvy muscular)
  @blood_types ~w(A B O AB)
  @drinking ~w(never rarely sometimes often)
  @smoking ~w(never rarely sometimes)
  @marriage_intent ~w(soon within_2_years someday undecided)
  @education ~w(高卒 専門卒 短大卒 大卒 大学院卒)
  @income_ranges ~w(~300万 300~500万 500~700万 700~1000万 1000万~)

  # ── Generate Users ──────────────────────────────────────────────────

  def generate_users(password_hash) do
    1..@user_count
    |> Enum.map(fn i ->
      phone = @fake_phone_prefix <> String.pad_leading(Integer.to_string(i), 6, "0")
      gender = if :rand.uniform() < 0.5, do: "female", else: "male"
      age = random_age()
      dob = Date.add(Date.utc_today(), -age * 365 - :rand.uniform(364))
      oid = Mongo.object_id()
      now = DateTime.utc_now()

      subscription = pick_subscription(gender)
      who_can = Enum.random(~w(inner_circle inner_circle inner_circle friends friends friends friends verified verified open))

      user_doc = %{
        _id: oid,
        phone_number: phone,
        password_hash: password_hash,
        gender: gender,
        date_of_birth: dob,
        age_verified: :rand.uniform() < 0.80,
        phone_verified: true,
        subscription: subscription,
        credits: if(subscription.plan == "free", do: 0, else: :rand.uniform(50)),
        matchmaker_settings: %{who_can_matchmake: who_can},
        invite_code: random_invite_code(),
        matchmaker_invites_sent: 0,
        refresh_tokens: [],
        inserted_at: now,
        updated_at: now
      }

      {oid, user_doc}
    end)
  end

  # ── Generate Profiles ───────────────────────────────────────────────

  def generate_profiles(users_with_ids, tags_by_category) do
    all_tags = Enum.flat_map(tags_by_category, fn {_cat, tags} -> tags end)

    users_with_ids
    |> Enum.with_index()
    |> Enum.map(fn {{oid, user}, idx} ->
      gender = user.gender
      richness = pick_richness()
      tag_count = pick_tag_count(richness)

      selected_tags =
        all_tags
        |> Enum.shuffle()
        |> Enum.take(tag_count)
        |> Enum.map(fn tag -> %{category: tag.category, value: tag.slug} end)

      {pref, city, _weight, [lng, lat]} = pick_prefecture()

      nickname = pick_name(gender)
      occupation = Enum.random(@occupations)
      bio = build_bio(pref, occupation)
      age = calculate_age_from_dob(user.date_of_birth)
      user_id_str = to_string(oid)

      # Assign a photo from the seed pool (100 per gender, cycling)
      photo_entry = build_photo_entry(gender, idx, user_id_str)
      # Strip internal metadata before storing in DB
      db_photo_entry = Map.delete(photo_entry, "_seed_source")

      {location_geo, location_name} = build_location(pref, city, lng, lat, richness)

      now = DateTime.utc_now()

      profile = %{
        user_id: user_id_str,
        display_name: nickname,
        nickname: nickname,
        bio: bio,
        gender: gender,
        age: age,
        location: location_geo,
        location_name: location_name,
        hometown: if(richness == :rich, do: Enum.random(["東京都", "大阪府", "神奈川県", "愛知県", "北海道", "福岡県", pref]), else: nil),
        physical: build_physical(richness),
        career: build_career(occupation, richness),
        lifestyle: build_lifestyle(richness),
        relationship: build_relationship(richness),
        personality: if(richness == :rich, do: Enum.random(["穏やか", "明るい", "真面目", "自由奔放", "几帳面"]), else: nil),
        photos: [db_photo_entry],
        photo_urls: [db_photo_entry["url"]],
        tags: selected_tags,
        tag_ids: Enum.map(selected_tags, fn t -> t.value end),
        visibility: %{},
        preferences: build_preferences(gender),
        inserted_at: now,
        updated_at: now
      }

      profile = Map.put(profile, :profile_completeness, calculate_completeness(profile))
      profile
    end)
  end

  # ── Social Graph ────────────────────────────────────────────────────

  def build_social_graph(fake_user_ids, me_oid) do
    now = DateTime.utc_now()

    # Pick 30 direct friends for "me"
    my_friends = Enum.take(Enum.shuffle(fake_user_ids), 30)
    {inner_circle_friends, regular_friends} = Enum.split(my_friends, 10)

    # Build friend connections for me
    my_friend_connections =
      Enum.map(inner_circle_friends, fn fid ->
        build_friend_connection(me_oid, fid, "inner_circle", "accepted", now)
      end) ++
      Enum.map(regular_friends, fn fid ->
        build_friend_connection(me_oid, fid, "friends", "accepted", now)
      end)

    # Pick 15 matchmakers for me (subset of my friends)
    my_matchmaker_ids = Enum.take(Enum.shuffle(my_friends), 15)

    my_matchmaker_connections =
      Enum.map(my_matchmaker_ids, fn mid ->
        build_matchmaker_connection(me_oid, mid, now)
      end)

    # Friends-of-friends: each of my 30 friends gets 5-10 of their own friends
    remaining_ids = fake_user_ids -- my_friends
    {fof_pool, background_pool} = Enum.split(Enum.shuffle(remaining_ids), 300)

    {fof_connections, fof_remaining} =
      Enum.reduce(my_friends, {[], fof_pool}, fn friend_id, {conns, pool} ->
        count = 5 + :rand.uniform(6)
        {chosen, rest} = Enum.split(pool, min(count, length(pool)))

        new_conns =
          Enum.map(chosen, fn fof_id ->
            tier = Enum.random(~w(friends friends verified))
            build_friend_connection(friend_id, fof_id, tier, "accepted", now)
          end)

        {conns ++ new_conns, rest}
      end)

    # ~50 matchmaker connections among FoF users
    fof_connected_ids = Enum.map(fof_connections, fn c -> c.recipient_id end) |> Enum.uniq()
    fof_matchmaker_pairs = fof_connected_ids |> Enum.shuffle() |> Enum.chunk_every(2, 2, :discard) |> Enum.take(50)

    fof_matchmaker_connections =
      Enum.map(fof_matchmaker_pairs, fn [subject, matchmaker] ->
        build_matchmaker_connection(subject, matchmaker, now)
      end)

    # ~300 background connections among remaining users (small clusters)
    background_connections = build_background_clusters(background_pool ++ fof_remaining, now, 300)

    all_connections =
      my_friend_connections ++
      my_matchmaker_connections ++
      fof_connections ++
      fof_matchmaker_connections ++
      background_connections

    all_connections
  end

  # ── Completeness Calculator (inline) ────────────────────────────────

  def calculate_completeness(profile) do
    scores = [
      {0.10, has_value?(profile, :nickname)},
      {0.10, has_location?(profile)},
      {0.20, has_photo?(profile)},
      {0.10, has_value?(profile, :bio)},
      {0.10, has_physical?(profile)},
      {0.10, has_career?(profile)},
      {0.05, has_lifestyle?(profile)},
      {0.10, has_relationship?(profile)},
      {0.10, has_tags?(profile)},
      {0.05, has_preferences?(profile)}
    ]

    scores
    |> Enum.reduce(0.0, fn {weight, present}, acc ->
      if present, do: acc + weight, else: acc
    end)
    |> Float.round(2)
  end

  # ── Orchestrator ────────────────────────────────────────────────────

  def run do
    Logger.info("=== Koikoi Fake Seeder ===")

    # Step 1: Clean up previous fake data
    Logger.info("Cleaning up previous fake data...")
    cleanup_fake_data()

    # Step 2: Load tags from DB
    Logger.info("Loading tags catalog from DB...")
    tags_by_category = load_tags()
    tag_count = Enum.reduce(tags_by_category, 0, fn {_cat, tags}, acc -> acc + length(tags) end)
    Logger.info("Loaded #{tag_count} tags across #{map_size(tags_by_category)} categories")

    if tag_count == 0 do
      Logger.error("No tags found in tags_catalog. Run seeds first: mix run -e \"Koikoi.Seeds.run()\"")
      exit(:no_tags)
    end

    # Step 3: Pre-compute password hash
    Logger.info("Computing Argon2 hash (one-time)...")
    password_hash = Argon2.hash_pwd_salt(@password)

    # Step 4: Generate users
    Logger.info("Generating #{@user_count} fake users...")
    users_with_ids = generate_users(password_hash)

    # Step 5: Generate profiles
    Logger.info("Generating profiles...")
    profiles = generate_profiles(users_with_ids, tags_by_category)

    # Step 6: Bulk insert users
    Logger.info("Inserting users in batches of #{@batch_size}...")
    user_docs = Enum.map(users_with_ids, fn {_oid, doc} -> doc end)

    user_docs
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, i} ->
      {:ok, _} = Mongo.insert_many(:mongo, "users", batch)
      Logger.info("  Users batch #{i}: #{length(batch)} inserted")
    end)

    # Step 7: Bulk insert profiles
    Logger.info("Inserting profiles in batches of #{@batch_size}...")

    profiles
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index(1)
    |> Enum.each(fn {batch, i} ->
      {:ok, _} = Mongo.insert_many(:mongo, "profiles", batch)
      Logger.info("  Profiles batch #{i}: #{length(batch)} inserted")
    end)

    # Step 8: Install photos into upload directories
    Logger.info("Installing profile photos...")
    install_photos(users_with_ids)

    # Step 9: Build social graph
    Logger.info("Building social graph...")
    me = Mongo.find_one(:mongo, "users", %{phone_number: "+81901111001"})

    if me do
      me_oid = me["_id"]
      fake_ids = Enum.map(users_with_ids, fn {oid, _doc} -> oid end)

      connections = build_social_graph(fake_ids, me_oid)
      Logger.info("Generated #{length(connections)} connections")

      # Bulk insert connections
      connections
      |> Enum.chunk_every(@batch_size)
      |> Enum.with_index(1)
      |> Enum.each(fn {batch, i} ->
        {:ok, _} = Mongo.insert_many(:mongo, "connections", batch)
        Logger.info("  Connections batch #{i}: #{length(batch)} inserted")
      end)
    else
      Logger.warning("Test user +81901111001 not found. Skipping social graph. Run seeds first.")
    end

    # Step 10: Print summary
    {:ok, user_count} = Mongo.count_documents(:mongo, "users", %{})
    {:ok, profile_count} = Mongo.count_documents(:mongo, "profiles", %{})
    {:ok, conn_count} = Mongo.count_documents(:mongo, "connections", %{})

    Logger.info("""
    === Seeding Complete ===
    Users:       #{user_count}
    Profiles:    #{profile_count}
    Connections: #{conn_count}
    """)
  end

  # ── Private Helpers ─────────────────────────────────────────────────

  defp seed_photos_dir do
    Path.join([File.cwd!(), "seeds", "users"])
  end

  defp upload_dir(user_id_str) do
    Path.join([:code.priv_dir(:koikoi), "static", "uploads", "photos", user_id_str])
  end

  defp build_photo_entry(gender, idx, user_id_str) do
    photo_idx = rem(idx, 100)
    gender_dir = if gender == "female", do: "female", else: "male"
    seed_filename = String.pad_leading(Integer.to_string(photo_idx), 3, "0") <> ".jpg"
    photo_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    %{
      "id" => photo_id,
      "url" => "/uploads/photos/#{user_id_str}/profile.jpg",
      "thumbnail_url" => "/uploads/photos/#{user_id_str}/thumb_profile.jpg",
      "order" => 0,
      "is_primary" => true,
      "_seed_source" => Path.join([gender_dir, seed_filename])
    }
  end

  defp install_photos(users_with_ids) do
    base_seed_dir = seed_photos_dir()

    users_with_ids
    |> Enum.with_index()
    |> Enum.each(fn {{oid, user}, idx} ->
      user_id_str = to_string(oid)
      gender_dir = if user.gender == "female", do: "female", else: "male"
      photo_idx = rem(idx, 100)
      seed_filename = String.pad_leading(Integer.to_string(photo_idx), 3, "0") <> ".jpg"
      source = Path.join([base_seed_dir, gender_dir, seed_filename])
      dest_dir = upload_dir(user_id_str)

      if File.exists?(source) do
        File.mkdir_p!(dest_dir)
        File.cp!(source, Path.join(dest_dir, "profile.jpg"))
        File.cp!(source, Path.join(dest_dir, "thumb_profile.jpg"))
      end
    end)

    Logger.info("  Installed photos for #{length(users_with_ids)} users")
  end

  defp cleanup_fake_data do
    # Delete fake users
    {:ok, del_users} = Mongo.delete_many(:mongo, "users", %{
      phone_number: %{"$regex" => "^\\+81903"}
    })
    Logger.info("  Deleted #{del_users.deleted_count} fake users")

    # Delete profiles belonging to fake users (user_id stored as string)
    # We need to find remaining profiles whose user_id doesn't match any real user
    # Simpler: delete profiles where user_id references a deleted user
    # Since we just deleted the users, find orphaned profiles
    # But user_id is stored as string — we collect the IDs before deleting...
    # Actually, let's just delete profiles whose user_id is not in remaining users
    # Easier approach: delete all profiles with phone-prefix pattern on user
    # But profiles don't have phone. So we find all real user IDs and delete profiles not matching.

    real_user_ids =
      Mongo.find(:mongo, "users", %{}, projection: %{_id: 1})
      |> Enum.map(fn u -> to_string(u["_id"]) end)
      |> MapSet.new()

    # Find profiles with user_id not in real users
    all_profile_user_ids =
      Mongo.find(:mongo, "profiles", %{}, projection: %{user_id: 1, _id: 1})
      |> Enum.to_list()

    orphan_profile_ids =
      all_profile_user_ids
      |> Enum.reject(fn p ->
        uid = to_string(p["user_id"])
        MapSet.member?(real_user_ids, uid)
      end)
      |> Enum.map(fn p -> p["_id"] end)

    if length(orphan_profile_ids) > 0 do
      {:ok, del_profiles} = Mongo.delete_many(:mongo, "profiles", %{
        _id: %{"$in" => orphan_profile_ids}
      })
      Logger.info("  Deleted #{del_profiles.deleted_count} orphaned profiles")
    else
      Logger.info("  No orphaned profiles to delete")
    end

    # Clean up orphaned connections
    real_user_oids =
      Mongo.find(:mongo, "users", %{}, projection: %{_id: 1})
      |> Enum.map(fn u -> u["_id"] end)
      |> MapSet.new()

    all_connections =
      Mongo.find(:mongo, "connections", %{}, projection: %{_id: 1, requester_id: 1, recipient_id: 1})
      |> Enum.to_list()

    orphan_conn_ids =
      all_connections
      |> Enum.reject(fn c ->
        MapSet.member?(real_user_oids, c["requester_id"]) and
        MapSet.member?(real_user_oids, c["recipient_id"])
      end)
      |> Enum.map(fn c -> c["_id"] end)

    if length(orphan_conn_ids) > 0 do
      orphan_conn_ids
      |> Enum.chunk_every(500)
      |> Enum.each(fn batch ->
        Mongo.delete_many(:mongo, "connections", %{_id: %{"$in" => batch}})
      end)
      Logger.info("  Deleted #{length(orphan_conn_ids)} orphaned connections")
    else
      Logger.info("  No orphaned connections to delete")
    end

    # Clean up uploaded photos for orphaned profiles
    uploads_base = Path.join([:code.priv_dir(:koikoi), "static", "uploads", "photos"])

    real_user_id_strings =
      Mongo.find(:mongo, "users", %{}, projection: %{_id: 1})
      |> Enum.map(fn u -> to_string(u["_id"]) end)
      |> MapSet.new()

    if File.exists?(uploads_base) do
      case File.ls(uploads_base) do
        {:ok, dirs} ->
          orphan_dirs = Enum.reject(dirs, fn d -> MapSet.member?(real_user_id_strings, d) end)
          Enum.each(orphan_dirs, fn d -> File.rm_rf!(Path.join(uploads_base, d)) end)
          if length(orphan_dirs) > 0 do
            Logger.info("  Cleaned up #{length(orphan_dirs)} orphaned photo directories")
          end
        _ -> :ok
      end
    end
  end

  defp load_tags do
    Mongo.find(:mongo, "tags_catalog", %{})
    |> Enum.to_list()
    |> Enum.group_by(fn tag -> tag["category"] end)
    |> Enum.into(%{}, fn {cat, tags} ->
      {cat, Enum.map(tags, fn t -> %{category: cat, slug: t["slug"], label_ja: t["label"]["ja"]} end)}
    end)
  end

  defp random_age do
    # Bell curve centered on 28-32
    base = 28 + :rand.normal() * 4
    base |> round() |> max(20) |> min(45)
  end

  defp pick_subscription(gender) do
    r = :rand.uniform()
    cond do
      r < 0.75 -> %{plan: "free", expires_at: nil}
      r < 0.95 ->
        # basic — mostly male
        if gender == "male" or :rand.uniform() < 0.3 do
          %{plan: "basic", expires_at: DateTime.add(DateTime.utc_now(), 30 * 24 * 3600, :second)}
        else
          %{plan: "free", expires_at: nil}
        end
      true ->
        %{plan: "vip", expires_at: DateTime.add(DateTime.utc_now(), 30 * 24 * 3600, :second)}
    end
  end

  defp random_invite_code do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper)
  end

  defp pick_richness do
    r = :rand.uniform()
    cond do
      r < 0.30 -> :rich
      r < 0.70 -> :medium
      true -> :sparse
    end
  end

  defp pick_tag_count(:rich), do: 5 + :rand.uniform(4)
  defp pick_tag_count(:medium), do: 3 + :rand.uniform(3)
  defp pick_tag_count(:sparse), do: 2 + :rand.uniform(2)

  defp pick_prefecture do
    r = :rand.uniform()
    {_acc, result} =
      Enum.reduce_while(@prefectures, {0.0, nil}, fn {pref, city, weight, coords}, {acc, _} ->
        new_acc = acc + weight
        if r <= new_acc do
          {:halt, {new_acc, {pref, city, weight, coords}}}
        else
          {:cont, {new_acc, nil}}
        end
      end)

    result || List.last(@prefectures)
  end

  defp pick_name("female"), do: Enum.random(@female_names)
  defp pick_name(_), do: Enum.random(@male_names)

  defp build_bio(prefecture, occupation) do
    template = Enum.random(@bio_templates)
    hobby = Enum.random(@hobby_phrases)

    template
    |> String.replace("__P__", prefecture)
    |> String.replace("__O__", occupation)
    |> String.replace("__H__", hobby)
  end

  defp build_location(pref, city, lng, lat, richness) do
    case richness do
      :rich ->
        jitter_lng = lng + (:rand.uniform() - 0.5) * 0.1
        jitter_lat = lat + (:rand.uniform() - 0.5) * 0.1
        geo = %{type: "Point", coordinates: [jitter_lng, jitter_lat]}
        {geo, "#{pref}#{city}"}

      :medium ->
        {nil, "#{pref}#{city}"}

      :sparse ->
        {nil, pref}
    end
  end

  defp build_physical(:rich) do
    %{
      height_cm: 150 + :rand.uniform(35),
      body_type: Enum.random(@body_types),
      blood_type: Enum.random(@blood_types)
    }
  end

  defp build_physical(:medium) do
    %{
      height_cm: 150 + :rand.uniform(35),
      body_type: nil,
      blood_type: nil
    }
  end

  defp build_physical(:sparse), do: %{}

  defp build_career(occupation, :rich) do
    %{
      occupation: occupation,
      education: Enum.random(@education),
      income_range: Enum.random(@income_ranges)
    }
  end

  defp build_career(occupation, :medium) do
    %{
      occupation: occupation,
      education: nil,
      income_range: nil
    }
  end

  defp build_career(_occupation, :sparse), do: %{}

  defp build_lifestyle(:rich) do
    %{
      drinking: Enum.random(@drinking),
      smoking: Enum.random(@smoking)
    }
  end

  defp build_lifestyle(:medium) do
    if :rand.uniform() < 0.5 do
      %{drinking: Enum.random(@drinking), smoking: nil}
    else
      %{}
    end
  end

  defp build_lifestyle(:sparse), do: %{}

  defp build_relationship(:rich) do
    %{
      marriage_intent: Enum.random(@marriage_intent),
      has_children: Enum.random([true, false, false, false]),
      wants_children: Enum.random([true, true, false, nil])
    }
  end

  defp build_relationship(:medium) do
    if :rand.uniform() < 0.5 do
      %{marriage_intent: Enum.random(@marriage_intent), has_children: nil, wants_children: nil}
    else
      %{}
    end
  end

  defp build_relationship(:sparse), do: %{}

  defp build_preferences(gender) do
    preferred = if gender == "male", do: ["female"], else: ["male"]
    %{
      age_range: %{min: 20 + :rand.uniform(5), max: 30 + :rand.uniform(15)},
      preferred_genders: preferred,
      preferred_prefectures: nil
    }
  end

  defp calculate_age_from_dob(%Date{} = dob) do
    today = Date.utc_today()
    age = today.year - dob.year

    # Handle leap year birthdays (Feb 29 -> use Mar 1 in non-leap years)
    birthday_this_year =
      case Date.new(today.year, dob.month, dob.day) do
        {:ok, date} -> date
        {:error, _} -> Date.new!(today.year, 3, 1)
      end

    if Date.compare(birthday_this_year, today) == :gt do
      age - 1
    else
      age
    end
  end

  defp calculate_age_from_dob(_), do: nil

  defp build_friend_connection(user_a, user_b, tier, status, now) do
    %{
      requester_id: user_a,
      recipient_id: user_b,
      type: "friend",
      trust_tier: tier,
      status: status,
      matchmaker_id: nil,
      subject_id: nil,
      inserted_at: now,
      updated_at: now
    }
  end

  defp build_matchmaker_connection(subject_id, matchmaker_id, now) do
    %{
      requester_id: subject_id,
      recipient_id: matchmaker_id,
      type: "matchmaker",
      trust_tier: "verified",
      status: "accepted",
      matchmaker_id: matchmaker_id,
      subject_id: subject_id,
      inserted_at: now,
      updated_at: now
    }
  end

  defp build_background_clusters(pool, now, target_count) do
    pool
    |> Enum.shuffle()
    |> Enum.chunk_every(6, 6, :discard)
    |> Enum.take(div(target_count, 3))
    |> Enum.flat_map(fn cluster ->
      # Each cluster: connect first to all others
      [hub | others] = cluster
      Enum.map(others, fn other ->
        tier = Enum.random(~w(friends verified))
        build_friend_connection(hub, other, tier, "accepted", now)
      end)
    end)
    |> Enum.take(target_count)
  end

  # ── Completeness Checks ────────────────────────────────────────────

  defp has_value?(profile, key) do
    val = Map.get(profile, key) || Map.get(profile, to_string(key))
    is_binary(val) and String.trim(val) != ""
  end

  defp has_location?(profile) do
    loc_name = Map.get(profile, :location_name) || Map.get(profile, "location_name")

    if is_binary(loc_name) and String.trim(loc_name) != "" do
      true
    else
      loc = Map.get(profile, :location) || Map.get(profile, "location") || %{}
      pref = Map.get(loc, :prefecture) || Map.get(loc, "prefecture")
      is_binary(pref) and String.trim(pref) != ""
    end
  end

  defp has_photo?(profile) do
    photos = Map.get(profile, :photos) || Map.get(profile, "photos") || []
    length(photos) >= 1
  end

  defp has_physical?(profile) do
    phys = Map.get(profile, :physical) || Map.get(profile, "physical") || %{}
    Enum.any?([:height_cm, :body_type, :blood_type, "height_cm", "body_type", "blood_type"], fn key ->
      val = Map.get(phys, key)
      val != nil and val != ""
    end)
  end

  defp has_career?(profile) do
    career = Map.get(profile, :career) || Map.get(profile, "career") || %{}
    Enum.any?([:occupation, :education, :income_range, "occupation", "education", "income_range"], fn key ->
      val = Map.get(career, key)
      is_binary(val) and String.trim(val) != ""
    end)
  end

  defp has_lifestyle?(profile) do
    ls = Map.get(profile, :lifestyle) || Map.get(profile, "lifestyle") || %{}
    Enum.any?([:drinking, :smoking, "drinking", "smoking"], fn key ->
      val = Map.get(ls, key)
      is_binary(val) and String.trim(val) != ""
    end)
  end

  defp has_relationship?(profile) do
    rel = Map.get(profile, :relationship) || Map.get(profile, "relationship") || %{}
    Enum.any?([:marriage_intent, :has_children, :wants_children, "marriage_intent", "has_children", "wants_children"], fn key ->
      val = Map.get(rel, key)
      val != nil and val != ""
    end)
  end

  defp has_tags?(profile) do
    tags = Map.get(profile, :tags) || Map.get(profile, "tags") || []
    length(tags) >= 3
  end

  defp has_preferences?(profile) do
    prefs = Map.get(profile, :preferences) || Map.get(profile, "preferences") || %{}
    genders = Map.get(prefs, :preferred_genders) || Map.get(prefs, "preferred_genders") || []
    length(genders) > 0
  end
end

Koikoi.FakeSeeder.run()
