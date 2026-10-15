extends Node3D
## ゲーム進行・持ち物・一時停止・クリア判定を管理する。
## クリア（部屋から脱出する）は、玄関ドアを開けて外の共用廊下（5階）へ出たとき。浴室から自室・玄関ホールへ出ただけでは脱出にならない。
## 通った区画の移り変わりで判定し、位置だけでは判定しない（ホールから廊下へ入った瞬間）。経路は浴室から出た方法で2通り：
##   正規ルート … 浴槽 → 換気口 → 換気経路 → ベランダへ降りる → 窓から自室 → 玄関ホール → 玄関ドア → 廊下（「正規ルートで脱出」）
##   裏技ルート … ドライバーでドアを直す → 玄関ホール → 玄関ドア → 廊下（「裏技ルートで脱出」）
## 操作：左クリック＝調べる・開閉・拾う／F＝選んだ持ち物を照準の対象に使う／1・2・ホイール＝持ち物を選ぶ／
##       Q＝選んだ持ち物を拡大して見る／E＝座る・浴槽に出入り／C＝しゃがむ
## 再プレイはシーンを読み込み直すので、ドライバー・ドア・所持品はすべて初期状態に戻る。

const RoomScript := preload("res://scripts/room.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")
const ExteriorScript := preload("res://scripts/exterior.gd")
const ApartmentScript := preload("res://scripts/apartment.gd")
const KotatsuScript := preload("res://scripts/kotatsu.gd")
const SmallPropsScript := preload("res://scripts/small_props.gd")
const FishingScript := preload("res://scripts/fishing.gd")
const HeadphoneAudio := preload("res://scripts/headphone_audio.gd")
const StoryData := preload("res://scripts/story_data.gd")
const IntercomScript := preload("res://scripts/intercom.gd")
const CorkGunScript := preload("res://scripts/cork_gun.gd")
const MahjongGame := preload("res://scripts/mahjong_game.gd")
const ProgressScript := preload("res://scripts/progress.gd")
const ClosetScriptRef := preload("res://scripts/closet.gd")
const RecordPlayerRef := preload("res://scripts/record_player.gd")
const MeshKit := preload("res://scripts/mesh_kit.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const SinkRef := preload("res://scripts/sink.gd")
const TowelRef := preload("res://scripts/towel.gd")
const BooksScript := preload("res://scripts/books.gd")
const TitleScript := preload("res://scripts/title_screen.gd")
const CorridorScript := preload("res://scripts/corridor.gd")
const CreditsData := preload("res://scripts/credits_data.gd")
const Stage3Items := preload("res://scripts/stage3_items.gd")
const Stage4Items := preload("res://scripts/stage4_items.gd")
const Stage5Items := preload("res://scripts/stage5_items.gd")
const JapaneseRoomScript := preload("res://scripts/japanese_room.gd")
const BurningTorchScript := preload("res://scripts/burning_torch.gd")

const MESSAGES := {
	"start": "……目が覚めると、トイレの中だった。ユニットバスの、自分の部屋の。ここから出て、部屋の外へ出なければ。",
	"toilet": "普通の便器だ。水は流れるが、ここから出られるわけではない。",
	"bathtub": "空っぽの浴槽。乾いていて、何も入っていない。",
	"bathtub_water": "浴槽に水がたまっている。",
	"bathtub_wet": "空の浴槽。底がまだ濡れている。",
	"sink": "小さな洗面台。……下に何か落ちている？",
	"vent": "換気口。格子の奥は暗く、よく見えない。",
	"poster": "水道修理の広告だ。連絡先は管理会社……スマホは部屋に置いてきた。",
	"bath_powder": "ユブロマン。ゆずの香りの入浴剤。今はのんびり浸かっている場合じゃない。",
	"bath_powder_pickup": "ユブロマンを手に入れた。ゆずの香りの入浴剤。",
	"powder_need_water": "もう少し水をためてから入れよう。",
	"powder_added": "ユブロマンを入れた。お湯がゆず色になっていく。",
	"powder_empty": "もう空っぽだ。",
	"bathtub_yuzu": "ゆず色のお湯がたまっている。いい香りがする。",
	"remote_off": "先に「運転」を押そう。",
	"remote_plug_open": "栓が抜けている。先に栓をしよう。",
	"remote_already_full": "もうお湯は設定の量まで入っている。",
	"remote_need_water": "お湯が少ないので追い焚きできない。",
	"washlet_need_sit": "座っているときだけ使える。",
	"remote_power_on": "運転を入れた。40℃。",
	"remote_power_off": "運転を切った。",
	"remote_auto_start": "ふろ自動：お湯はりを始めた。",
	"remote_auto_done": "ふろ自動：お湯はりが終わった。",
	"remote_reheat_start": "追い焚きを始めた。",
	"remote_reheat_done": "追い焚きが終わった。",
	"remote_reheat_low": "お湯が少なくなったため、追い焚きを中断した。",
	"remote_stopped": "お湯はり・追い焚きを止めた。",
	"washlet_rear_on": "おしり：作動中。",
	"washlet_bidet_on": "ビデ：作動中。",
	"washlet_stopped": "洗浄を止めた。",
	"washlet_stood_up": "立ったので、洗浄が止まった。",
	"paper_holder": "いつものトイレットペーパー。ここだけは平常運転だ。",
	"spare_roll": "『明日もある』。今日の分は、なんとかしてほしい。",
	"toilet_cleaner": "『無かったことに』。閉じ込められた件にも効くだろうか。",
	"plunger": "ラバーカップ。ブラシと妙にきれいに並んでいる。",
	"toilet_brush": "トイレブラシ。ここでの仕事には慣れていそうだ。",
	"vent_sticker": "『点検済。異常なし。たぶん。』……たぶん？",
	"ladder_lowered": "ボロボロのはしごを、出口から下ろした。錆びていて、段が何本か抜けている。ぎしぎし言っている。",
	"lean_out": "手すりに手をかけて、身を乗り出した。……思ったより、高い。路地が、ずっと下に見える。",
	"ko_line": "右手の遠くに、高架の線路。KO線だ。電車が、ゆっくり走っていく。",
	"bucket_pick": "水色の大きな風呂桶を拾った。逆さにして浴槽に置けば、足場になりそうだ。",
	"bucket_placed": "風呂桶を逆さにして、浴槽の底に置いた。上に乗れそうだ。",
	"vent_far": "天井の換気口。手が届かない。もう少し背が高ければ……。",
	"vent_stretch": "背伸びをしたら、ぎりぎり届いた。格子を押し上げ、体を引き上げた。",
	"lever_pull": "ガコン。……壁が、床が、震えはじめた。",
	"lever_stuck": "レバーは動かない。固まっている。",
	"inspect_lever": "鏡の奥の、赤い握りのレバー。『点検用』と小さく書いてある。引くな、とは書いていない。",
	"wood_stick": "壊れた扉の枠の破片。細長い木の棒だ。拾った。",
	"fuse_hatch": "柱の面に、小さな扉。ノブがない。丸い穴だけが空いている。",
	"cabinet_locked": "鏡の扉は開かない。右端に溝付きの留め具がある。",
	"cabinet_locked_mirror": "鏡の扉は開かない。右端に溝付きの留め具がある。……鏡の奥に、手かがみのような物が刺さって見える。いまは、取れない。",
	"cabinet_unlocked": "留め具を外した。鏡の扉が開けられる。",
	"bath_bucket": "風呂桶。軽いプラスチック製だ。",
	"shampoo": "シャンプー。側面のギザギザで、目を閉じていても分かる。",
	"rinse": "リンス。こちらはつるつるしている。",
	"razor": "髭剃り。刃はまだ新しい。",
	"face_wash": "洗顔料。泡立ちがいいらしい。",
	"toner": "化粧水。ほとんど減っていない。",
	"cotton_swabs": "綿棒。ぎっしり詰まっている。",
	"driver": "ドライバーを手に入れた。",
	"door_locked": "ドアノブが空回りする。開かない。",
	"door_loose": "ドアノブのネジがゆるんでいる。ドライバーが使えそうだ。",
	"spare_roll_pickup": "『明日もある』。予備ロールを手に入れた。",
	"paper_holder_empty": "芯だけになっている。紙がない。",
	"cover_closed": "先にカバーを開けよう。",
	"paper_installed": "新しいロールに替えた。外した芯は小皿に置いた。",
	"holder_full": "まだ紙が残っている。",
	"cannot_use": "ここでは使えない。",
	"tub_note": "小さな紙が貼ってある。『ここまで来たか。』",
	"towel_scratch": "タオルの裏に傷がある。前からあっただろうか。",
	"bath_light_off": "カチッ。トイレの電気を消した。",
	"bath_light_on": "カチッ。トイレの電気をつけた。",
	"bath_light_purple": "カチッ……電球がちらついて、トイレが青白い光に包まれた。",
	"bath_light_on_purple": "カチッ。トイレが青白い蛍光灯のようにともった。",
	"bath_light_normal": "カチッ……ちらついて、光がもとの白に戻った。",
	"tub_no_plug": "浴槽に栓がない。排水口がむき出しだ。",
	"sink_no_plug": "洗面台にも栓がない。排水口がぽっかり開いている。",
	"coin10_pickup": "古い十円玉が、傷のくぼみに挟まっていた。",
	"coin10_hint": "丸いものは、ふたになる。",
	"coin_on_sink": "十円玉を排水口に置いた。ぴったりふさがった。",
	"coin_on_tub": "十円玉を排水口に置いた。……軽くて、水の勢いで浮いてしまいそうだ。",
	"lid_with_sinker": "十円玉の上に、おもりを載せた。ふたが安定した。",
	"sinker_alone": "おもりだけでは、穴はふさげない。",
	"coin_taken_back": "十円玉を拾い上げた。",
	"soap_pickup": "洗面台の下に、固形せっけんが落ちていた。拾った。",
	"soap_placed": "せっけんを洗面台の水に沈めた。……ゆっくり溶けていく。",
	"soap_dry": "洗面台に、水が溜まっていない。",
	"soap_dissolved": "せっけんが溶けて、中から重たい鉛のおもりが現れた。",
	"sinker_pickup": "鉛のおもりを手に入れた。ずっしり重い。",
	"ball_sunk": "粉の中から、固い玉がひとつ沈んだ。水では、色がにじむだけだ。",
	"ball_dissolved": "お湯で玉が溶けた。中から、ドライバーが出てきた。",
	"tub_driver_pickup": "ドライバーを手に入れた。",
	"shower_hold": "シャワーを手に取った。向けた方へ、水が飛ぶ。",
	"shower_back": "シャワーを元に掛けた。",
	"curtain_sprayed": "手に取ったシャワーを、カーテンにかけた。うっすらと数字が浮かんでいる……。",
	"lint_hint": "服に、毛だまりがびっしりついている。……洗えば取れそうだ。",
	"lint_washed": "服が、さっぱりした。排水口の近くに、毛だまりが流れ着いた。",
	"lint_pickup": "毛だまりを手に入れた。ふわふわで、まっすぐ飛ぶ矢が作れそうだ。",
	"paper_pickup": "壁のメモをはがした。英語が書いてあるが、文字がひっくり返っている。",
	"paper_mirror": "鏡に映った文字は、英語だった。『FLUSH』。",
	"paper_wall": "壁に紙が貼ってある。文字がひっくり返っていて、読めない。",
	"aircon_on": "ピッ。エアコンがついた。羽が開いて、風がゆるく降りてくる。",
	"aircon_off": "ピッ。エアコンを止めた。",
	"fan_on": "扇風機がまわり出した。首がゆっくり振れる。",
	"fan_off": "扇風機を止めた。",
	"kitchen_sink": "小さな流し台。蛇口をひねっても、水は出ない。",
	"kitchen_stove": "ガスコンロにやかんがのっている。火はついていない。",
	"fridge": "冷蔵庫だ。牛乳は入っている。電池と石は……冷やすものではない。",
	"guitar": "ギターだ。弦を1本はじくと、ずいぶん長く鳴った。",
	"taxidermy": "何の動物なのか、まったく分からない剥製が、釘に刺さっている。目の数が合わない。",
	"phone_black": "黒電話だ。受話器を上げても、どこにもつながらない。リリリン、と鳴っただけだった。",
	"phone_mobile": "みかんの鉢に携帯が刺さっている。画面は暗い。圏外だ。",
	"kotatsu_look": "こたつだ。座布団がある。……あったかそう。",
	"kotatsu_inside": "こたつの中は、赤くてあたたかい。WASD で中を這える。布団の外まで進むと、抜けられる。",
	"kotatsu_exit": "こたつの反対側へ抜けた。",
	"rug": "厚手のじゅうたん。赤地にひし形の模様。足の裏がふかふかする。",
	"cellar_opened": "床板の蓋を持ち上げた。冷たい空気が上がってくる。",
	"cellar_closed": "蓋を閉めた。ぱたん、と床にもどった。",
	"cellar_carry_taken": "{food}を持った。傷まないうちに、冷蔵庫に入れよう。",
	"cellar_carry_full": "もう両手がふさがっている。先に、いま持っているものを冷蔵庫へ入れよう。",
	"fridge_put": "{food}を冷蔵庫に入れた。床下の食べ物は、あと{left}つ。",
	"stairs_revealed": "床下の底板が、ごとり、と外れた。暗い階段が、下へ続いている。",
	"cellar_sack": "米袋。生米は食べられない。炊飯器もないし。",
	"cellar_potato": "じゃがいもが転がっている。芽が出かけている。生では食べられない。",
	"cellar_goods": "床下の貯蔵庫だ。階段はない。米袋、漬物の壺、缶詰、瓶、じゃがいも。食べ物ばかりだ。",
	"card_box": "トランプのケース。中身は出して遊んだまま、空だ。",
	"cup": "湯のみ。お茶はまだ少しぬるい。",
	"tissue": "ティッシュ箱。一枚つまみ出されたままになっている。",
	"magazines": "雑誌の山。ぜんぶ、読みかけの付箋が挟まっている。",
	"teddy": "くまのぬいぐるみが、枕のそばに座っている。こちらをじっと見ている。",
	"aquarium": "水槽。",
	"aquarium_fed": "えさをまくと、メダカがいっせいに水面へ寄ってきた。アロワナは、ゆっくり上から見下ろしている。",
	"aquarium_full": "さっきあげたばかりだ。食べすぎはよくない。",
	"fridge_upper_opened": "冷凍室を開けた。氷とアイスと冷凍の豆。",
	"fridge_lower_opened": "冷蔵室を開けた。牛乳、ジャム、卵のパック。",
	"fridge_closed": "ぱたん、と閉めた。",
	"fridge_inside": "牛乳、ジャム、タッパー。電池と石も入っている。電池と石は……冷やすものではない。",
	"egg_taken": "卵をひとつ取った。いま持っている卵：{n}個。残り{left}個。",
	"egg_hands_full": "もう手に持てない。3つまでだ。",
	"stove_on": "カチカチ……ボッ。コンロに火がついた。青い炎がフライパンの下で揺れる。",
	"stove_off": "火を止めた。",
	"stove_crack": "卵を割ってフライパンに落とした。ジュッ。",
	"stove_wait": "まだ白身が透けている。もう少し待とう。",
	"stove_eat_1": "目玉焼きができた。立ったまま食べた。しょうゆがほしい。",
	"stove_eat_2": "二つ目の目玉焼き。さすがに塩気が欲しくなってきた。",
	"stove_eat_3": "もう卵を食べすぎだ。そろそろやめよう。",
	"stove_burnt_clear": "こげた卵を捨てた。フライパンは黒くなっている。",
	"coin_pickup": "タンクの底から、金色のコインを拾った。表にエイリアンの絵。クレーンゲームのコインだ。",
	"ufo_no_coin": "コインの投入口がある。コインがないと動かない。",
	"fishing_rod": "室外機のうしろに立てかけてあった釣り竿を手に入れた。ベランダの手すりから、下の路地へ糸を垂らせそうだ。",
	"fish_need_rod": "手すりの下は路地だ。ここから釣り糸を垂らしたら、何か釣れるかもしれない。釣り竿があれば……。",
	"fish_cast_msg": "手すりから、釣り糸を路地へ垂らした。浮きが跳ねるまで待とう。",
	"fish_early": "まだ何もかかっていない。糸をたぐり寄せた。",
	"fishing_text": "{text}",
	"radio_ch1": "ラジオ。ゆったりしたピアノのコードが流れている。",
	"radio_ch2": "ラジオ。どこかで聞いたことのあるような、ないような小曲。",
	"radio_ch3": "ラジオ。ニュースらしい。男の人が何か言っているが、言葉は聞き取れない。",
	"radio_ch4": "ラジオ。時報だ。ピッ、ピッ、ピッ、ポーン。",
	"radio_off": "ラジオを消した。",
	"wall_clock": "壁掛け時計。いまは{time}。針はちゃんと動いている。",
	"mahjong": "ふとんの山の上に、麻雀牌のケースがのっていた。麻雀牌を手に入れた。こたつの中で F を押すと、一人麻雀が打てる。",
	"record_disc": "壁に飾ってあったレコード盤を外した。ほんのり埃のにおいがする。",
	"record_set": "レコード盤をターンテーブルにのせた。針を落とすと、パチパチという雑音のあとで、古いジャズが流れ出した。",
	"record_empty": "ターンテーブルは空っぽだ。壁に飾ってあるレコード盤を使えそうだ。",
	"record_stopped": "針を上げた。部屋が急に静かになる。",
	"record_started": "針を落とした。パチパチという音のあとで、古いジャズが流れ出す。",
	"record_jacket_1": "ジャケット『夜の余白』（MIDNIGHT JAZZ）。月夜のピアノの絵。中身は空の袋だ。",
	"record_jacket_2": "ジャケット『留守番のブルース』。椅子がひとつ、夕日の部屋に残っている。中身は空の袋だ。",
	"record_jacket_3": "ジャケット『配管に雨が降る』。サックスと配管、屋根の猫。中身は空の袋だ。",
	"record_jacket_4": "ジャケット『午前二時の冷蔵庫』。夜の街へ開いた冷蔵庫の絵。中身は空の袋だ。",
	"game_cover_5": "ソフトのケース。『こたつ麻雀』。こたつの上に牌が並び、猫が丸まって寝ている。……架空のゲームだ。",
	"game_cover_6": "ソフトのケース。『地下七段』。赤い提灯の階段が下へ。……七段、なのか。架空のゲームだ。",
	"game_cover_7": "ソフトのケース。『留守のレコード』。ターンテーブルと、陽のあたる部屋。……架空のゲームだ。",
	"book_new_1": "『正しい石の洗い方』。石は洗うものらしい。せっけん置きに載せるのが正しいそうだ。",
	"book_new_2": "『階段はどこまで家なのか』。階段だらけの家の絵。答えは書いていない。",
	"book_new_3": "『ひとり分の麻雀』。表紙に、ぽつんと牌がひとつ。",
	"book_new_4": "『この手紙は地下で読むこと』。赤い階段の上に、封筒が浮いている。……もう読んだ。",
	"book_new_5": "『石はなぜ黙っているのか』。浮かぶ石と、ひとりの旅人。答えは「石だから」らしい。",
	"book_new_6": "『昨日を売る店』。夕焼けの瓶が並ぶ店先に、猫。昨日はいくらだろう。",
	"book_new_7": "『冷蔵庫の奥にある町』。雪の町の絵。……奥までは、まだ見ていない。",
	"book_new_8": "『留守のあいだに増えた部屋』。扉だらけの迷路の絵。赤い扉だけが光っている。",
	"microwave": "電子レンジ。中には何も入っていない。",
	"game_cover_1": "ソフトのケース。『下南澤、午前二時』。赤い月の下の路地に、女の子がひとり。……架空のゲームだ。",
	"game_cover_2": "ソフトのケース。『団地の向こう側』。空へ伸びる階段を、女の子が見上げている。……架空のゲームだ。",
	"game_cover_3": "ソフトのケース。『最後の留守番』。陽だまりの部屋で、ロボットが床を拭いている。……架空のゲームだ。",
	"game_cover_4": "ソフトのケース。『風呂から帰れない』。浴槽の向こうに、荒れた海と赤い夕日。……他人事とは思えない。",
	"mj_start": "牌をじゃらじゃらと広げる。一人麻雀のはじまりだ。",
	"mj_quit": "牌を片づけた。",
	"mj_need_kotatsu": "麻雀はこたつの中で打つものだ（なぜか）。",
	"cork_gun": "冷蔵庫の上に、細長いおもちゃのピストルが寝ていた。コルク銃を手に入れた。F で撃てる。",
	"figure": "棚のフィギュア。……撃ち落とせそうな高さだ。",
	"standee": "等身大パネル。巨大な髪と、ワインレッドのコート。……自分の姿だ。いつ作ったのだろう。裏は、後ろ姿まできちんと印刷されている。",
	"hood_1": "換気扇「弱」。ごうごう……と、ゆるやかに空気を吸い込む。",
	"hood_2": "換気扇「中」。羽がぐんと速くなって、音も大きくなった。",
	"hood_3": "換気扇「狂」。ゴオオオオッ！ フードが壊れそうに震えて、ランプが赤く点滅した。",
	"hood_off": "換気扇を止めた。台所が急に静かになる。",
	"toilet_slippers": "トイレ用のスリッパ。つま先に「WC」と書いてある。",
	"shoes": "玄関に靴。スニーカーは片方が倒れている。革靴はきちんとそろっている。……履く機会はまだない。",
	"clothes": "脱ぎっぱなしのシャツとズボン、靴下。そろそろ洗濯しないと。",
	"dumbbell": "ダンベル。持ち上げようとしたが、やめた。三日坊主のあとだ。",
	"bottle": "空のペットボトルが転がっている。",
	"bag": "コンビニの袋から、ネギが飛び出している。買った覚えはない。",
	"intercom_idle": "インターホンのモニター。画面は暗い。呼び出しがあると、玄関の外が映るらしい。",
	"intercom_visitor": "モニターに、玄関の外の人影が映っている。じっとこちらを見ている。……インターホンは、鳴らしただけだ。",
	"intercom_after": "インターホンのモニター。画面には、誰もいない廊下が映っている。",
	"tv_on": "ピッ。テレビがついた。",
	"tv_off": "ピッ。テレビを消した。",
	"tv_start": "ゲームを始めた。W／A／S／D（矢印キー）で操作する。E か Esc でやめる。",
	"tv_stop": "ゲームをやめた。",
	"ufo_miss": "アームが降りて……景品をつかみそこねた。",
	"ufo_win": "景品をつかんだ。取り出し口に落ちた。持ち帰れはしないらしい。",
	"ufo_empty": "景品は、もうない。",
	"life_paper_02": "古い映画の再上映。半券を捨てずに取ってある。",
	"life_paper_07": "石好きの会。ここなら話が合いそうだ。",
	"shelf_note": "棚の裏に小さな紙が貼ってある。『下からなら見える。』",
	"tank_note": "タンクの下の壁に小さな紙。『しゃがむと、いろいろ見える。』",
	"door_fixed": "ドライバーでドアノブのネジを締め直した。……ドアが開いた！",
	"no_headroom": "頭上が狭くて、ここでは立ち上がれない。",
	"sleep_in": "ふとんにもぐって、あおむけに寝ころんだ。天井の木目が、顔のように見える気がする。",
	"sleep_out": "起き上がった。体が少し軽い。",
	"bed": "小さな寝床。敷きっぱなしのふとんと、枕、青いブランケット。E で寝られる。",
	"no_way_out": "出る場所がふさがっている。",
	"closet_in": "押入れの中は、真っ暗だ。襖の合わせ目から、細い光がもれている。……落ち着く。",
	"closet_quiet": "……静かだ。ここなら、誰にも見つからない。",
}

## 状態で変わる操作の案内。設備スクリプトの get_prompt() がキーを返す
const PROMPTS := {
	"examine": "左クリック：調べる",
	"lid_open": "左クリック：蓋を開ける",
	"lid_close": "左クリック：蓋を閉める",
	"seat_up": "左クリック：便座を上げる",
	"seat_down": "左クリック：便座を下ろす",
	"water_on": "左クリック：水を出す",
	"water_off": "左クリック：水を止める",
	"coin10_take": "左クリック：十円玉を取る",
	"lid_remove": "左クリック：ふたを外す",
	"lid_set": "左クリック：ふたを戻す",
	"curtain_spray": "左クリック：シャワーをカーテンにかける",
	"plug_pull": "左クリック：栓を抜く",
	"plug_insert": "左クリック：栓をする",
	"tank_open": "左クリック：タンクの蓋を開ける",
	"tank_close": "左クリック：タンクの蓋を戻す",
	"cabinet_open": "左クリック：鏡の扉を開ける",
	"cabinet_close": "左クリック：鏡の扉を閉める",
	"window_open": "左クリック：窓を開ける",
	"window_close": "左クリック：窓を閉める",
	"flush": "左クリック：水を流す",
	"remote_power": "左クリック：運転",
	"remote_auto": "左クリック：ふろ自動",
	"remote_reheat": "左クリック：追い焚き",
	"remote_stop": "左クリック：停止",
	"washlet_rear": "左クリック：おしり",
	"washlet_bidet": "左クリック：ビデ",
	"washlet_stop": "左クリック：止",
	"towel_slide": "左クリック：タオルをずらす",
	"towel_back": "左クリック：タオルを戻す",
	"cover_open": "左クリック：カバーを開ける",
	"cover_close": "左クリック：カバーを閉める",
	"curtain_close": "左クリック：カーテンを閉める",
	"shower_on": "左クリック：シャワーを出す",
	"shower_off": "左クリック：シャワーを止める",
	"curtain_open": "左クリック：カーテンを開ける",
	"kotatsu_enter": "左クリック：こたつに入る",
	"cellar_open": "左クリック：床下の蓋を開ける",
	"cellar_close": "左クリック：床下の蓋を閉める",
	"cellar_examine": "左クリック：床下を調べる",
	"hood_press": "左クリック：換気扇のボタン",
	"cellar_carry": "左クリック：持って運ぶ",
	"cellar_stairs_go": "左クリック：地下へ降りる",
	"basement_up_go": "左クリック：階段を上がる",
	"cellar_look": "左クリック：調べる",
	"tv_play": "左クリック：テレビゲームで遊ぶ",
	"cards_draw": "左クリック：トランプを一枚めくる",
	"dice_roll": "左クリック：サイコロを振る",
	"tv_remote": "左クリック：テレビの電源",
	"game_case": "左クリック：このソフトに入れ替える",
	"coin_take": "左クリック：コインを拾う",
	"catch_look": "左クリック：調べる",
	"fish_need_rod_prompt": "左クリック：調べる",
	"fish_cast": "左クリック：釣り糸を垂らす",
	"fish_wait": "左クリック：引き上げる（まだ早いかも）",
	"fish_reel": "左クリック：引き上げる！",
	"radio_on": "左クリック：ラジオをつける",
	"radio_next": "左クリック：チャンネルを変える",
	"aquarium_feed": "左クリック：えさをやる",
	"fridge_open": "左クリック：冷蔵庫を開ける",
	"fridge_close": "左クリック：冷蔵庫を閉める",
	"fridge_look": "左クリック：中を見る",
	"egg_take": "左クリック：卵を取る",
	"stove_ignite": "左クリック：コンロに火をつける",
	"stove_crack_prompt": "左クリック：卵を割って焼く",
	"stove_off_prompt": "左クリック：火を止める",
	"stove_wait_prompt": "左クリック：焼き上がりを見る",
	"stove_eat_prompt": "左クリック：目玉焼きを食べる",
	"stove_clear_prompt": "左クリック：こげた卵を捨てる",
	"front_door_open": "左クリック：玄関のドアを開ける",
	"bath_door_open": "左クリック：トイレのドアを開ける",
	"fusuma_open_l": "左クリック：左の襖を開ける（ふとんを見る）",
	"fusuma_open_r": "左クリック：右の襖を開ける（つかみどりを見る）",
	"fusuma_close": "左クリック：襖を閉める",
	"bath_door_close": "左クリック：トイレのドアを閉める",
	"book_read": "左クリック：本を読む",
	"bath_light_off": "左クリック：トイレの電気を消す",
	"bath_light_on": "左クリック：トイレの電気をつける",
	"aircon_on": "左クリック：エアコンをつける",
	"aircon_off": "左クリック：エアコンを止める",
	"fan_on": "左クリック：扇風機をつける",
	"fan_off": "左クリック：扇風機を止める",
	"ufo_play": "左クリック：アームを動かす",
	"record_set": "左クリック：レコード盤をのせる",
	"record_empty": "左クリック：調べる",
	"record_play": "左クリック：針を落とす",
	"record_stop": "左クリック：針を上げる",
}

## 持ち物（拾える物）。最大2つ。1・2 キーは取った順
const ITEMS := {
	"driver": {"name": "ドライバー", "desc": "赤橙の柄のドライバー。先はプラス。"},
	"spare_roll": {"name": "予備ロール", "desc": "包装されたトイレットペーパー。『明日もある』。"},
	"fishing_rod": {"name": "釣り竿", "desc": "竹色の釣り竿。リールがついている。ベランダの手すりから、下の路地へ糸を垂らせそうだ。"},
	"cork_gun": {"name": "コルク銃", "desc": "細長いおもちゃのピストル。銃口にコルクが詰まっている。F で撃つ。棚のフィギュアを狙えそうだ。"},
	"mahjong": {"name": "麻雀牌", "desc": "深緑のケースに入った麻雀牌。ずっしり重い。こたつの中で、F で一人麻雀が打てそうだ。"},
	"record_disc": {"name": "レコード盤", "desc": "壁に飾ってあった黒いレコード盤。赤いラベルに、かすれた文字で『MIDNIGHT BLUE ROOM』。レコードプレーヤーにのせられそうだ。"},
	"ufo_coin": {"name": "UFOコイン", "desc": "クレーンゲーム用のコイン。表にエイリアンの絵。1回ぶん。"},
	"bath_powder": {"name": "ユブロマン", "desc": "ゆずの香りの粉末入浴剤。1回分。"},
	"soap": {"name": "固形せっけん", "desc": "ピンクの固形せっけん。水に浸けておくと、溶けていく。"},
	"ten_yen": {"name": "十円玉", "desc": "古い十円玉。丸いものは、ふたになる。"},
	"match_stick": {"name": "マッチ棒", "desc": "1 本だけのマッチ。箱には『火事の元』と印字されていた。"},
	"room_key": {"name": "部屋の鍵", "desc": "ベランダの窓の鍵。……玄関の鍵ではない。"},
	"torch": {"name": "松明", "desc": "木の棒の先に、火がついている。部屋が暗くても、まわりだけは見える。"},
	"door_knob": {"name": "壊れたドアノブ", "desc": "壊れたドアノブ。ホールの柱の、小さな扉の穴に合いそうだ。"},
	"fuse": {"name": "ヒューズ", "desc": "小さなヒューズ。ブレーカーに差せそうだ。"},
	"hand_mirror": {"name": "手かがみ", "desc": "金の縁の、丸い手かがみ。光を、ほかの場所へはね返せる。"},
	"pickaxe": {"name": "大きなツルハシ", "desc": "宝石の中から出てきた、大きなツルハシ。壁を壊せそうだ。"},
	"crystal": {"name": "結晶", "desc": "紫の小さな結晶。……筒の先につけたら、遠くが見えるかもしれない。"},
	"bm_dog": {"name": "栞（犬）", "desc": "犬の影絵が描かれた栞。"},
	"bm_monkey": {"name": "栞（猿）", "desc": "猿の影絵が描かれた栞。"},
	"bm_pheasant": {"name": "栞（キジ）", "desc": "キジの影絵が描かれた栞。"},
	"lighter": {"name": "ライター", "desc": "赤い使い捨てライター。ちゃんと火がつく。ごく小さな明かりになる。"},
	"wood_ladder": {"name": "はしご", "desc": "古い木のはしご。浮き上がった浴室へ、立てかけられそうだ。"},
	"photo_tkg": {"name": "写真『おふくろのTKG』", "desc": "『おふくろのTKG』と書かれた写真。裏に、レシピが書いてある：ご飯と卵で『冷めたTKG』を作り、電子レンジでチンする。"},
	"rice_pack": {"name": "パックご飯", "desc": "温めるだけのパックご飯。……あたためなくても食べられるが、冷たい。"},
	"cold_tkg": {"name": "冷めたTKG", "desc": "ご飯に卵をかけただけの、冷めたTKG。電子レンジでチンすると、ちゃんとした TKG になるらしい。"},
	"tkg": {"name": "TKG", "desc": "おふくろの、TKG。湯気が立っている。……食べよう。"},
	"flashlight": {"name": "小さな懐中電灯", "desc": "小さな懐中電灯。ライターより明るい光が、前へ、細く伸びる。"},
	"magnifier": {"name": "虫眼鏡", "desc": "古い虫眼鏡。小さな文字が、大きく読める。"},
	"magnet_hook": {"name": "磁石付きの釣り針", "desc": "磁石の付いた釣り針。金属の物が、釣れやすくなる。"},
	"earplugs": {"name": "耳栓", "desc": "オレンジの耳栓。F でつけ外しする。つけると、まわりの音が小さくなる。"},
	"home_key": {"name": "家の鍵", "desc": "赤いタグの付いた鍵。玄関のドアの鍵だ。"},
	"blowgun_part": {"name": "吹き矢の材料", "desc": "細い筒の吹き口と口金。トイレットペーパーの芯と、何かの羽根があれば、吹き矢になりそうだ。"},
	"mahjong_tiles": {"name": "麻雀牌（東・中）", "desc": "麻雀牌が 2 枚。『東』と『中』。"},
	"bad_book": {"name": "悪口本", "desc": "表紙も中身も、真っ黒に塗りつぶされた本。何が書いてあるのか、読めない。……水に流したら、どうなるだろう。"},
	"tp_core": {"name": "トイレットペーパーの芯", "desc": "ホルダーから外した、紙の芯。筒になっている。"},
	"tp_core2": {"name": "使い切った芯", "desc": "予備ロールを使い切って残った芯。筒になっている。"},
	"telescope": {"name": "望遠鏡", "desc": "芯の先に、紫の結晶をはめた。のぞくと、遠くの小さな物が大きく見える。"},
	"blowgun": {"name": "吹き矢", "desc": "芯の筒に、口金と吹き口をつけ、毛だまりで矢羽根を作った。矢は 100 本まで。ベランダから、向かいの的を狙えそうだ。"},
	"medal": {"name": "メダル", "desc": "九蓮宝燈で、なぜか出てきたメダル。つかみ取りに入れられそうだ。"},
	"small_pickaxe": {"name": "小さなツルハシ", "desc": "ちいさな、ちいさなツルハシ。壁を叩くと、ほんの少しだけ、削れる。……少しだけ。"},
	"headphones": {"name": "ヘッドホン", "desc": "こたつの中に落ちていた、古いヘッドホン。手に持つと、耳につける。持ち物から外すと、聞こえなくなる。"},
	"blank_card_0": {"name": "白紙のトランプ", "desc": "何も書かれていない、白いカード。普通の明かりの下では、ただの白紙だ。"},
	"blank_card_1": {"name": "白紙のトランプ", "desc": "何も書かれていない、白いカード。普通の明かりの下では、ただの白紙だ。"},
	"blank_card_2": {"name": "白紙のトランプ", "desc": "何も書かれていない、白いカード。普通の明かりの下では、ただの白紙だ。"},
	"blank_card_3": {"name": "白紙のトランプ", "desc": "何も書かれていない、白いカード。普通の明かりの下では、ただの白紙だ。"},
	"prize_list": {"name": "景品一覧表", "desc": "つかみ取りの景品の一覧表。順番が書いてある。"},
	"bad_book_wet": {"name": "濡れた悪口本", "desc": "水に濡れて、黒が落ちた本。最後のページに『悪いことは、水に流そう。』と書いてある。"},
	"yen100": {"name": "百円玉", "desc": "ぴかぴかの百円玉。自動販売機で使えそうだ。"},
	"sinker": {"name": "鉛のおもり", "desc": "ずっしり重い鉛の塊。軽いものの上に載せれば、重しになる。"},
	"lint": {"name": "毛だまり", "desc": "服についていた毛玉と綿ぼこり。ふわふわで軽い。"},
	"paper": {"name": "鏡文字のメモ", "desc": "英語が書いてあるが、文字がひっくり返っている。鏡にかざせば読めそうだ。"},
	"bucket": {"name": "風呂桶", "desc": "水色の大きな風呂桶。軽いプラスチック製。逆さにすれば、足場になりそうだ。"},
	"wood_stick": {"name": "木の棒", "desc": "壊れた扉の枠の破片。細長い木の棒。先に何かを巻けば、松明の柄になりそうだ。"},
}

## E キーで変わる姿勢の案内
const ACTION_PROMPTS := {
	"sit": "E：座る",
	"stand_up": "E：立つ",
	"tub_enter": "E：浴槽に入る",
	"tub_exit": "E：浴槽から出る",
	"vent_enter": "E：換気口へ入る",
	"vent_far": "E：手を伸ばす",
	"shower_return": "E：シャワーを戻す",
	"vent_stretch": "E：背伸びして換気口へ",
	"ladder_lower": "E：はしごを下ろす",
	"lean_out": "E：手すりから身を乗り出す",
	"lean_back": "E：身を戻す",
	"duct_back": "E：浴室へ戻る",
	"balcony_down": "E：はしごでベランダへ降りる",
	"kotatsu_sit": "E：こたつに座る",
	"closet_enter": "E：押し入れに入る",
	"closet_exit": "E：押し入れから出る",
	"ladder_up": "E：はしごで、浴室へ上る",
	"ladder_down": "E：はしごで、ホールへ下りる",
	"kotatsu_stand": "E：立つ",
	"kotatsu_out": "E：こたつから出る",
	"sleep": "E：ふとんで寝る",
	"get_up": "E：起きる",
}

# 寝床（ふとんの上）。頭は枕のある東（+x）。目は敷布団の面から 0.2m、ほぼ真上を見る
const BED_FEET := Vector3(2.95, 0.27, 1.98)
const BED_YAW := -PI * 0.5
const BED_EYE := 0.2
const BED_EXITS := [Vector3(1.7, 0.0, 1.98), Vector3(1.7, 0.0, 1.75), Vector3(1.7, 0.0, 2.15)]   # ふとんの西のはし（南側はこたつとのすき間が狭く立てない）

const SINK_TARGETS := ["sink", "sink_plug", "sink_faucet", "sink_soap"]   # 十円玉を置ける照準先（洗面台のどこか）
const MIRROR_TARGETS := ["mirror_door", "mirror_lock"]
const TUB_TARGETS := ["bathtub", "bath_plug", "bath_faucet", "tub_note"]   # 入浴剤を使える照準先（浴槽のどこか）

## 調べたときに鳴らす効果音（fixture のない対象）
const INTERACT_SFX := {"guitar": "strum", "fridge": "thunk", "kitchen_stove": "click", "phone_mobile": "click", "kitchen_sink": "click", "cards": "page", "card_box": "click", "dice": "click", "cup": "click", "tissue": "rustle", "magazines": "page", "teddy": "rustle", "standee": "click", "toilet_slippers": "rustle", "shoes": "click", "clothes": "rustle", "bag": "rustle", "dumbbell": "clunk", "bottle": "click", "tv_remote": "beep", "rug": "rustle"}
const CLEAR_TITLES := {"legit": "正規ルートで脱出", "shortcut": "裏技ルートで脱出", "true": "真のクリア", "neighbor": "お隣さんの窓から脱出"}
## 百円で、ベランダの下の自動販売機の「炭酸リンゴジュース」を買う結末（シナリオ v3 の「二つの結末」）。
## 部屋を出たとき百円玉を持っていると、そこではクリアにならず、廊下のエレベーターで 1 階へ降りられる。
const ENDING := {
	"yen_hint": "百円玉を握りしめている。……このまま帰るのは、もったいない気がする。廊下の奥にエレベーターがある。",
	"elevator_ride": "エレベーターを呼ぶと、箱はすぐに来た。5 階から、1 階へ。",
	"elevator_arrive": "1 階だ。扉が開いた。",
	"lobby": "郵便受けが並んだ玄関ホール。アーチの向こうに、路地が見える。",
	"vending_look": "ベランダの真下にある、白い自動販売機。見上げれば、ベランダの手すりが見える。",
	"vending_far": "いちばん上の段のボタンに、手が届かない……。炭酸リンゴは、最上段だ。もう少し背が高ければ。",
	"vending_no_money": "お金が足りない。",
	"vending_coin": "百円玉を入れた。いちばん上の段、炭酸リンゴジュース。ボタンを押す。",
	"vending_drop": "ガコン。取り出し口に、冷たい缶が落ちてきた。",
	"vending_drink": "プシュッ。……しゅわしゅわと、喉を鳴らす。",
	"vending_last": "……あの鍵のことは、水に流そう。",
	"vending_voice": "……よく、頑張ったね。",
}
const CLOSET_EYE := 0.8                # 押入れの中に座ったときの目の高さ
## 段階 3（暗い部屋）の説明。停電中は、電気の物は使えず、調べると説明だけが出る。
const STAGE3 := {
	"match_caught": "マッチ棒が釣れた。……たった 1 本だ。箱には『火事の元』と書いてあったらしい。",
	"key_caught": "部屋の鍵が釣れた。ベランダの窓の鍵だ。……玄関の鍵ではない。",
	"window_locked": "窓には鍵がかかっている。部屋の鍵がいる。",
	"window_unlocked": "カチッ。窓の鍵が開いた。",
	"torch_made": "木の棒の先に、マッチで火をつけた。松明ができた。",
	"torch_voice": "松明は、危ない。",
	"torch_thrown": "松明は、窓の外へ飛んでいった。ベランダの床で、ぱちぱちと燃えている。",
	"torch_out": "松明の火が、ぷすっと消えた。",
	"knob_pickup": "壊れたドアノブを拾った。",
	"hatch_open": "ドアノブをつけて、小さな扉を開けた。中に、小さなヒューズが入っている。入れる広さではない。",
	"fuse_pickup": "ヒューズを手に入れた。",
	"breaker_closed": "ねじが、ひとつ。ドライバーが使えそうだ。",
	"breaker_no_fuse": "ヒューズがない。",
	"breaker_done": "ブレーカーは、ちゃんと入っている。",
	"breaker_cover_open": "ねじを回すと、蓋が開いた。",
	"breaker_cover_first": "ヒューズを差したいが、蓋がねじで閉まっている。",
	"breaker_on": "ヒューズを差し込んだ。カチッ。……部屋の電気が、ついた。",
	"dark_hint": "電気は、どこから来ているのだろう。",
	"hatch_hint": "ドアノブのない扉が、あった。",
	"stick_match_hint": "棒の先に、火をつけられそうだ。",
	"key_hint": "鍵はどこかに落ちていないか。下を見てみよう。",
	"no_power": "電気がない。動かない。",
}
## 停電中に使えない物（id → 調べたときの説明）。「game_case_」「ufo_」で始まる id も同じ。
const POWER_DEAD := {
	"tv_play": "テレビは、真っ暗だ。電気がない。",
	"tv_remote": "リモコンを押しても、何も起きない。",
	"record_player": "ターンテーブルは動かない。電気がない。",
	"radio": "ラジオは、ノイズも出ない。電気がない。",
	"microwave": "電子レンジは動かない。",
	"intercom": "インターホンは、真っ暗だ。",
	"kotatsu": "こたつがある。電気がないと、暖かくない。",
	"bed": "ふとんがある。……いま眠っている場合ではない。",
}
## ホールのお酒のセラーの説明（調べる）と、動かない置物の説明。
const LIQUOR := {
	"liquor_cellar": "透明な扉のお酒のセラー。変なラベルの瓶と缶が、六本。冷えている。……ぜんぶ、飲む気にはなれない。",
	"liquor_1": "『終電の抜け殻』（缶）。夜空に浮かぶ電車の絵。乗り過ごしたあとの、静けさの味がするらしい。",
	"liquor_2": "『配管ブルース』（缶）。むき出しの管と、サックスを吹く影。蛇口をひねると、ジャズが流れそうだ。",
	"liquor_3": "『冷蔵庫の満月』（瓶）。満月の前に、小さな冷蔵庫。……中身も、ずいぶん冷えている。",
	"liquor_4": "『午前零時の蛇口』（瓶）。蛇口から、星がこぼれている。零時ちょうどに開ける酒らしい。",
	"liquor_5": "『留守番酒』（瓶）。崖の上の家に、ひとつだけ灯った窓。待っている間に飲むやつ。",
	"liquor_6": "『石の寝言』（瓶）。眠る石の絵。……ときどき、中で寝返りを打つ音がする。",
	"ornament": "手の込んだ置物。コルク銃で撃っても、びくともしなさそうだ。",
	"broken": "お酒は20歳になってから。",
}
## 段階 4（隣の和室）の説明。
const STAGE4 := {
	"mirror_pickup": "手かがみを手に入れた。",
	"mirror_stuck": "鏡に、手かがみのような物が刺さっている。……扉の向こうだ。いまは、取れない。",
	"gem_look": "大きな宝石。展示札には『触ると普通』とある。……ぼんやり、紫に光っている。",
	"gem_look_mirror": "大きな宝石。手かがみで、何かの光を当てたら……？",
	"gem_bright": "部屋が明るくて、反射が見えない。暗くしないと。",
	"gem_no_light": "トイレの明かりが消えている。はね返す光がない。",
	"gem_white": "光は白い。宝石は、反応しない。……青い光でないとだめらしい。",
	"gem_far": "宝石が遠すぎる。もう少し近づいて、向きを合わせよう。",
	"gem_break": "手かがみで青い光をはね返すと、宝石にひびが走った。……パリン。宝石が砕けた！",
	"gem_after": "宝石の台座には、結晶が残り、足元には、大きなツルハシが転がっている。",
	"pickaxe_pickup": "大きなツルハシを手に入れた。",
	"crystal_pickup": "結晶を手に入れた。",
	"wall_look": "こたつの中なのに、壁がある。ひびが入っていて、向こうから、かすかに畳のにおいがする。",
	"wall_hard": "硬い。素手では、びくともしない。",
	"wall_break": "ツルハシを振り下ろした。ガツン！ ……壁が崩れて、暗い穴が開いた。",
	"wall_hole": "崩れた壁の向こうは、暗い。畳のにおいが濃くなった。",
	"washitsu_in": "暗くて、質素な和室だ。……ここは、誰の家だろう。",
	"back_in_kotatsu": "こたつの中へ戻った。",
	"scroll_blotch": "掛け軸には、墨の模様が、バラバラに散っている。見る高さで、何かに見えそうだ。",
	"scroll_aligned": "ぴったりの高さで見ると、墨が犬、猿、キジの影絵に揃った。上から、犬、猿、キジ。",
	"scroll_dark": "掛け軸がある。暗くて、何も見えない。明かりがほしい。",
	"heirloom_look": "漆の小さな箱。前に、細い差し込み口が三つある。栞のような物を差せそうだ。",
	"heirloom_done": "箱は、もう開いている。",
	"slot_ok": "カチリ。栞が差さった。（%d / 3）",
	"slot_wrong": "栞は入らない。順番が、ちがうのかもしれない。掛け軸が、手がかりだ。",
	"heirloom_open": "三つの栞がそろうと、箱の蓋が、静かに開いた。",
	"photo_pickup": "写真が入っていた。『おふくろのTKG』。裏には、レシピが書いてある。",
	"god_silent": "……神の声が、黙った。",
	"hint_silent": "……なにも、聞こえない。",
	"grandma": "おばあちゃんの写真。……どこかで、見たことのある笑顔だ。",
	"kamidana": "神棚。小さな社に、ほこりが積もっていない。毎日、誰かが手を合わせていたのだ。",
	"ranma_low": "高い所に、彫刻がある。もう少し背が高ければ、見えそうだ。",
	"ranma_high": "欄間の彫刻。犬と、猿と、鳥が、並んでいる。……掛け軸と、同じ順だ。",
	"town_map": "下南澤のミニチュア。コーポヨシミの 5 階の窓に、小さな灯りが一つだけ描いてある。",
	"mouse_hole": "ねずみ穴。目の高さを低くしたら、見つけられた。小さな穴の奥に、何かが転がっている気配がする。……あの隅の床の、光る物のことだろうか。",
	"ladder_pickup": "古い木のはしごを手に入れた。浮き上がった浴室へ、立てかけられそうだ。",
	"coin_pickup": "暗い隅に、コインが落ちていた。UFOキャッチャーのコインだ。",
	"coin_dark": "暗くて、よく見えない。何か、光る物が落ちている気がする。",
	"lighter_pickup": "ブレーカーの箱の隅に、ライターが入っていた。",
	"bookmark_found": "ページのあいだに、栞が挟まっていた。『%s』。",
	"need_light": "暗くて、何も見えない。明かりがほしい。",
	"ladder_placed": "はしごを、浮き上がった浴室へ立てかけた。上り下りできそうだ。（はしごを狙って E）",
	"ladder_up": "はしごを上って、浴室へ戻った。",
	"ladder_down": "はしごを下りて、ホールへ戻った。",
	"rice_pickup": "パックご飯を手に入れた。……卵があれば、あれが作れそうだ。",
	"need_egg": "ご飯に合わせる卵がいる。冷蔵庫から、卵を取ってこよう。",
	"cold_tkg_made": "ご飯に卵をかけた。……冷めた TKG だ。これを、電子レンジでチンする。",
	"microwave_start": "冷めた TKG を、電子レンジに入れた。……ブーン。",
	"microwave_done": "チン！ ……おふくろの TKG が、できあがった。",
	"tkg_eat": "いただきます。……うまい。なぜか、少しだけ、涙が出た。",
}
## 栞が挟まっている本（題名 → 栞の id）。順番は、掛け軸の影絵（犬 → 猿 → キジ）。
const BOOKMARK_BOOKS := {"透明な隣人": "bm_dog", "影の標本室": "bm_monkey", "椅子の渡り鳥": "bm_pheasant"}
const BOOKMARK_ORDER := ["bm_dog", "bm_monkey", "bm_pheasant"]
const BOOKMARK_KIND := {"bm_dog": "dog", "bm_monkey": "monkey", "bm_pheasant": "pheasant"}
const GEM_REACH := 2.4
## 段階 5（トイレへ戻る・つかみ取り）の説明。
const STAGE5 := {
	"front_door_locked": "玄関のドアは、鍵がかかっている。家の鍵がいる。",
	"front_door_unlock": "カチャリ。玄関の鍵が開いた。",
	"star_figure": "棚のフィギュア。……背中に、黄色い星の印がある。",
	"star_hit": "命中！ 星の印のフィギュアが落ちた。……足元で、何かがきらりと光った。",
	"shot_coin": "コインが落ちていた。UFOキャッチャーのコインだ。",
	"prize_flashlight": "景品『小さな懐中電灯』が出た。ライターより明るい。",
	"prize_magnifier": "景品『虫眼鏡』が出た。小さな文字が読めそうだ。",
	"prize_magnet_hook": "景品『磁石付きの釣り針』が出た。釣りで、金属の物が出やすくなる。",
	"prize_earplugs": "景品『耳栓』が出た。つけると、音が小さくなる。",
	"prize_rice_pack": "景品『パックご飯』が出た。……卵があれば、あれが作れる。",
	"prize_home_key": "景品『家の鍵』が出た。玄関のドアの鍵だ！",
	"prize_blowgun_part": "景品『吹き矢の材料』が出た。筒の口と口金だ。",
	"prize_mahjong_tiles": "景品『麻雀牌（東・中）』が出た。",
	"earplugs_on": "耳栓をつけた。まわりの音が、小さくなった。",
	"earplugs_off": "耳栓を外した。",
	"magnifier_use": "虫眼鏡で見る。……小さな文字は、狙った先にあるはずだ。",
	"bad_book_pickup": "椅子の上に、真っ黒に塗りつぶされた本があった。表紙も、中身も、読めない。",
	"flush_need_lid": "便器の蓋が閉まっている。本を流すなら、蓋を開けよう。",
	"flush_not_here": "便器のそばで、使おう。",
	"flush_book": "本を便器に落として、レバーを引いた。ゴボゴボゴボ……。",
	"clog": "ごぼっ。……詰まった。水位が、じわじわ上がってくる。もう、流れない。",
	"book_back": "水の底から、本が浮かんできた。黒が落ちて、文字が読める。ページのあいだから、コインが 1 枚、こぼれ落ちた。",
	"phone_coin": "「7・3・0・5」。……ジー、カチャッ。『ただいま、お取り込み中です』。ガチャン。受話器の下の返却口から、コインが落ちてきた。",
	"phone_empty": "「7・3・0・5」。『ただいま、お取り込み中です』。……返却口は、もう空っぽだ。",
	"feed_look": "水槽のフタの上に、赤い餌箱がある。5 つのダイヤルの鍵がかかっている。文字のダイヤルのようだ。",
	"feed_open": "かちっ。餌箱が開いた。中から、コインが 1 枚、水槽の底へ、ちゃぽん、と沈んでいった。",
	"feed_wrong": "ダイヤルを合わせてみたが、開かない。",
	"feed_opened": "餌箱は開いている。中は空だ。",
	"aq_coin_msg": "水槽の底の砂の上に、コインが沈んでいる。手を入れて、拾った。",
	"dish_core_pick": "小皿の芯を取った。トイレットペーパーの芯だ。",
	"paper_pull": "紙を引いた。くるくる……。まだ、ある。",
	"paper_out": "ガラガラガラ……。紙が、なくなった。芯だけが残った。",
	"paper_core2": "使い切った芯を取った。",
	"telescope_make": "芯の先に、結晶をはめた。……望遠鏡ができた。",
	"telescope_far": "のぞいてみた。遠くが、少しだけ大きく見えた。",
	"ceiling_dot": "天井に、小さな点がある。布団に寝ていたら、気になったかもしれない。……肉眼では、よく見えない。",
	"ceiling_look": "望遠鏡で、天井の点をのぞいた。点は、小さな文字だった。『九蓮宝燈』。",
	"medal_get": "九蓮宝燈……！　なぜか、メダルがこぼれ出た。",
	"medal_use": "メダルを入れた。ガシャン、ガシャン……",
	"medal_yen": "取り出し口から、百円玉が転がり出てきた。メダルが、百円玉に変わった。",
	"blowgun_make": "筒に口金と吹き口をつけ、毛だまりを矢羽根にした。……吹き矢ができた。",
	"blowgun_need_balcony": "吹き矢は、ベランダから使おう。",
	"blowgun_hidden": "向かいの壁に、的があるような気がする。庇が邪魔でよく見えない。……背伸びをすれば、見えるだろうか。（目の高さを上げる：]）",
	"blowgun_none": "ぷっ。……矢は、壁まで届かず、下へ落ちていった。",
	"blowgun_miss": "ぷっ。矢が、向かいの壁に刺さった。（のこり %d 本）",
	"blowgun_hit": "ぷっ。……カッ！　的に当たった！　どこかで、コインが落ちる音がした。",
	"blowgun_out": "矢は、もう 1 本もない。",
	"dart_coin_get": "ベランダの床に、コインが落ちていた。ラストのコインだ。",
	"magnifier_feed": "虫眼鏡で、餌箱の鍵を見た。ダイヤルのまわりに、小さな字。『ミラー』……鏡にうつして読む、ということだろうか。",
	"magnifier_safe": "虫眼鏡で、金庫を見た。くぼみのふちに、小さな点が並んでいる。……8、6、4、2。大きいほうから、らしい。",
	"magnifier_dot": "虫眼鏡で天井の点を見た。……まだ小さい。もっと遠くを見る道具が、いる。",
	"wall_w_look": "隔て板だ。薄い。向こうは、お隣のベランダのようだ。",
	"wall_e_look": "隔て板だ。薄い。向こうは、釣り竿の側……おばあちゃんの部屋のベランダのようだ。",
	"wall_hit": "ガツン。",
	"wall_q1": "板が、ミシッと鳴った。",
	"wall_q2": "ひびが入ってきた。",
	"wall_q3": "もう少しで、割れそうだ。",
	"wall_w_break": "バキィッ！　隔て板が割れた。お隣のベランダが、つながった。",
	"wall_e_break": "バキィッ！　隔て板が割れた。おばあちゃんの部屋のベランダが、つながった。",
	"granny_balcony": "おばあちゃんのベランダだ。……ずいぶん、静かだ。奥に、大きな道具箱がある。",
	"neighbor_balcony": "お隣のベランダだ。奥の窓が開いていて、部屋の明かりがもれている。",
	"chest_open": "釣りの道具箱だ。ふたを開けると、釣りで手に入る物が、種類ごとに、ずらりと並んでいた。",
	"chest_small": "箱の底に、小さなツルハシが 1 本あった。もらっていこう。",
	"small_have": "また、小さなツルハシが釣れた。……もう、持っている。",
	"duct_sound": "耳栓をしたら、ダクトのうなりが消えた。……トン、トン、トトン。壁の向こうから、規則正しい音がする。こたつの奥のほうこうだ。",
	"hp_pick": "こたつの中に、ヘッドホンが落ちていた。誰かの物だろうか。",
	"hp_on": "ヘッドホンを耳につけた。……ざあ、とノイズが鳴って、誰かの話し声が聞こえてくる。",
	"hp_voice": "二人の声。くぐもっていて、何を話しているのか、聞き取れない。……片方は、自分の声に似ている気がする。",
	"hp_bgm": "話し声が途切れて、ゆっくりした、不思議な音楽が流れはじめた。聞いたことが、ある気がする。",
	"hp_off": "ヘッドホンを外した。音が、遠くなった。",
	"hp_loading": "ヘッドホンをつけた。……ざあ、とノイズだけが鳴っている。",
	"drop_ok": "%s を、そこに置いた。",
	"drop_none": "置く物を、手に持とう。（1〜8 かホイール）",
	"drop_no": "それは、置けない。",
	"drop_here": "ここには、置けない。",
	"placed_pick": "%s を、拾った。",
	"card_pick": "白いカードが落ちていた。何も書かれていない。……まだ、あと何枚かありそうだ。",
	"safe_look": "押入れの隅に、小さな金庫がある。上に、カードを置くくぼみが 4 つ並んでいる。",
	"safe_place": "カードをくぼみに置いた。かちっ。",
	"safe_wrong": "ぶーっ。カードがはね返された。置く順番が違うらしい。",
	"safe_open": "かちゃん。金庫が開いた。中に、景品の一覧表が入っていた。",
	"safe_empty": "金庫は開いている。もう、何もない。",
	"safe_need4": "くぼみは 4 つ。カードは、4 枚そろえたい。",
	"toilet_clogged": "つまっていて、流れない。水があふれそうだ。（ほかの設備は、使える）",
}
## つかみ取りの景品（固定順）。コイン 1 枚で、1 つずつ出る。
const CARD_DOTS := [2, 4, 6, 8]
const PRIZES := ["flashlight", "magnifier", "magnet_hook", "earplugs", "rice_pack", "home_key", "blowgun_part", "mahjong_tiles"]
const VENDING_REACH := 1.49            # 自動販売機の最上段のボタンに届く目の高さ（150 cm）。最後の関門が身長
const RIDE_STOPS := [4, 3, 2, 1]
# 換気経路：入口で浴槽へ戻れる範囲（換気口の真上からの水平距離）、出口からベランダへ降りる経由点と着地候補
const DUCT_BACK_RANGE := 0.75
const DUCT_YAW := -PI * 0.5   # 入ったら +x（自室の上の方）を向く
const VENT_BELOW := Vector3(-0.72, 1.6, -1.02)       # 換気口の真下（足元の経由点）
const VENT_MOUTH := Vector3(-0.72, 2.45, -1.0)       # 換気口の中（足元の経由点）
const DUCT_EXIT_MOUTH := Vector3(1.9, 2.5, -1.45)    # 外壁の出口の外（足元の経由点）
const BALCONY_LANDINGS := [Vector3(1.7, 0.0, -1.7), Vector3(2.0, 0.0, -1.7), Vector3(1.6, 0.0, -1.65)]

# 便器に座る位置（足元）と目の高さ、立つときに戻る通路側の候補
const SEAT_FEET := Vector3(-0.46, 0.0, 0.0)
const SEAT_YAW := -PI * 0.5          # +x（部屋の中央）を向く
const SEAT_EYE := 1.12
const SEAT_EXITS := [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.35), Vector3(0.05, 0.0, -0.2), Vector3(0.2, 0.0, 0.45)]
# 浴槽の中の位置（足元は浴槽の底）と目の高さ、出るときの候補
const TUB_FEET_LOCAL := Vector3(-0.05, 0.10, 0.0)   # 浴槽ローカル（浴槽の中心が原点）
const TUB_YAW := -PI * 0.5           # 蛇口と栓のある +x を向く
const TUB_EYE := 0.75                # 足元から。水面（最高 0.50m）より上
const TUB_BODY_HEIGHT := 0.8
# 浴槽の縁（z=-0.45）・洗面台（x≥0.52）・便器（x≤-0.3）に体（半径0.25）が重ならない位置
const TUB_EXITS := [Vector3(0.05, 0.0, -0.15), Vector3(0.1, 0.0, 0.1), Vector3(0.0, 0.0, 0.5)]

const AudioSettingsScript := preload("res://scripts/audio_settings.gd")
const SETTINGS_PATH := "user://settings.cfg"
const PROMPT_EXAMINE := "左クリック：調べる"
const PROMPT_PICKUP := "左クリック：拾う"
const PROMPT_REPAIR := "左クリック：ドライバーで直す"

var has_driver := false          # ドライバーを持っているか（使っても消費しない）
var inventory: Array[String] = []   # 持ち物の id（取った順）
var selected := -1                  # 選択中の番号（なければ -1）
var _item_models := {}              # 拡大表示用の3Dモデル（拾ったときに複製）
var powder_used := false           # ユブロマンを使った（空の容器は所持品に残る）
var route_duct := false            # 換気経路を通ってベランダへ降りた
var clear_route := ""              # "legit" / "shortcut"（クリアした経路）
var region := ""                   # 今いる区画：bath / hall / room / duct / balcony / corridor
var _last_region := ""
var door_open := false
var cleared := false
var _mw_busy := false
var earplugs_on := false
var _flash_light: SpotLight3D
var shot_coin_node: Node3D
var shot_coin_taken := false
var safe_list_taken := false
var memos_found: Array = []        # 見つけたメモの id（teddy など）
var muttered := {}                 # 出した独り言（場所・順番）
var _mutter_next := 150.0          # 次の独り言を出す遊んだ時間（秒）
var _mutter_idle_i := 0
var _reader_after: Callable
var phone_coin_taken := false
var medal_given := false
var txn := 0                       # 取引の最中（購入・メダル交換・クレーン）。この間は、保存を後回しにして、置く・捨てるも止める
var _ufo_txn := false
var _prize_pending := false
var _duct_heard := false
var vending_busy := false
var wall_hits := {"w": 0, "e": 0}   # 隔て板を叩いた回数（大きなツルハシ 62 回、小さなツルハシ 1994 回で割れる）
var _wall_hold := 0.0
var _neighbor_seen := false
var _granny_seen := false
var chest_small_taken := false
var _hp_audio := HeadphoneAudio.new()
var _hp_player: AudioStreamPlayer
var _hp_on := false
var placed_items: Array = []        # 置いた持ち物 {id, node}
const DARTS_MAX := 100
var darts_used := 0
var cards_in_safe: Array = []      # 金庫に置いたカード（番号）。順番を間違えると戻る
var cards_taken: Array = []        # 拾ったカード（番号）
var god_silent := false            # 家宝の写真を取ると、神の声が黙る（エンディングの一言だけは出る）
var washitsu_transit := false
var _ambient_before := -1.0
var _scroll_a := 0.0
var _torch_base := 1.6
var thrown_torch: Node3D           # ベランダに捨てた、燃える松明
var _torch_light: OmniLight3D      # 松明を手に持ったときの明かり
var _torch_t := 0.0
var _dark_hinted := false
var power_restored := false        # ブレーカーにヒューズを差して、部屋の電気が戻った
var closet_hiding := false         # 押入れに閉じこもっている
var credits_enabled := true        # クリアの前にエンドロールを流す（テストでは切る）
var ride_speed := 1.0              # エレベーターの待ち時間の速さ（テストでは速める）
var riding := false                # エレベーターに乗っている間
var vending_done := false          # 自動販売機で買った（真のクリアへ）
var paused := false
var play_time := 0.0               # 一時停止中を除くプレイ時間（秒）。空模様に使う
var kotatsu_seat := 0              # 座っている（入っている）こたつの座布団（KotatsuScript.SEATS の番号）
var peeping := false               # のぞき穴の画面が開いている
var coding := false                # 数字・文字の入力画面が開いている
var _code_buf := ""
var _code_len := 4
var _code_digits := true
var _code_title := ""
var _code_prompt := ""
var _code_cb: Callable
var reading := false               # 本を読む画面が開いている
const TISSUE_SHEETS := 12
var coin_count := 0                # 持っている UFOコインの枚数
var coins_total := 0               # 集めたコインの枚数（使った分も数える。クリアの記録用）
var items_found := {}              # 一度でも手に入れた持ち物の id（クリアの記録用）
var _item_tutorial_shown := false
var has_lint := true                # 服に毛だまりがついているか（洗うと取れる）
var _lint_hinted := false
var _lint_wash := 0.0
var tissue_pulled := 0             # ティッシュを引いた回数
var progress: Node                  # ヒント・発見・セーブ（progress.gd）
var examined := {}                 # 調べた物の id（調べた数の記録。軽い集合だけ）
var total_examinable := 0           # 調べられる物の数（始めに数える）
var gaming := false                # テレビゲームで遊んでいる
var mj_playing := false            # 一人麻雀を打っている
var mj_cursor := 13
var mahjong: RefCounted
var _rng := RandomNumberGenerator.new()
var _reader_pages: Array = []
var _reader_page := 0
var _reader_title := ""
var _reader_cover: Texture2D
var _reader_tint := Color.WHITE
var _reader_opened_frame := -1

## 調べると、推理ノートに自動で書かれる手がかり：調べた物の id → [題, 本文, 種類]
const NOTE_CLUES := {
	"tub_note": ["浴槽の紙", "『ここまで来たか。』", "手がかり"],
	"shelf_note": ["棚の裏の紙", "『下からなら見える。』", "手がかり"],
	"tank_note": ["タンクの下の紙", "『しゃがむと、いろいろ見える。』", "手がかり"],
	"towel_scratch": ["タオルの裏の傷", "丸いくぼみと、水の波のような五本線。傷の中に十円玉が挟まっていた。", "手がかり"],
	"sink_soap": ["洗面台の下のせっけん", "固形せっけん。水に浸けたら、溶けそうだ。", "手がかり"],
}
const EYE_STEP := 0.02   # [ と ] で変える、目の高さの 1 回ぶん（m）

var _lever_busy := false
var _lean_x := 2.5
var _ko_seen := false
static var _title_seen := false   # 起動後、タイトル画面を一度出したか（やり直しの再読み込みでは出さない）
var _title: Node

var room: RoomScript
var fishing: Node3D                # ベランダの釣り（fishing.gd）
var player: PlayerScript
var hud: HudScript


func _ready() -> void:
	# メインは一時停止中も Esc を受け取れるようにする。プレイヤーと部屋は止める。
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_setup_input_map()

	var sfx := SfxScript.new()   # 効果音（コードで作る。assets/audio/sfx/ にファイルを置くと差し替わる）
	sfx.name = "Sfx"
	add_child(sfx)
	room = RoomScript.new()
	room.name = "Room"
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)

	player = PlayerScript.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.global_position = room.spawn_position
	player.interact_requested.connect(_on_interact_requested)
	player.surface_fn = _surface_at
	room.bath_remote.notice.connect(func(key: String) -> void: hud.show_message(MESSAGES[key]))
	player.crouch_blocked.connect(func() -> void: hud.show_message(MESSAGES["no_headroom"]))
	var books = room.apartment.books
	books.player = player
	books.read_requested.connect(_open_reader)


	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_pressed.connect(_resume)
	hud.quit_pressed.connect(_quit)
	hud.retry_pressed.connect(_retry)
	hud.eye_height_changed.connect(_on_eye_height_changed)
	hud.audio_changed.connect(_on_audio_changed)
	hud.head_bob_changed.connect(_on_head_bob_changed)
	hud.body_visible_changed.connect(_on_body_visible_changed)
	hud.sensitivity_changed.connect(_on_sensitivity_changed)
	hud.typing_changed.connect(_on_typing_changed)
	hud.hints_changed.connect(_on_hints_changed)
	hud.hint_requested.connect(_on_hint_requested)
	room.unit_risen.connect(_on_unit_risen)
	room.sink.soap_dissolved.connect(func() -> void:
		if not progress._loading:
			SfxScript.play("plop")
			hud.show_message(MESSAGES["soap_dissolved"], 5.0)
			progress.discover("soap_dissolved")
			progress.add_note("sinker", "せっけんの中のおもり", "洗面台のせっけんが溶けて、鉛のおもりが出てきた。重い。", "手がかり"))
	room.bathtub.ball_sunk.connect(func() -> void:
		if not progress._loading:
			hud.show_message(MESSAGES["ball_sunk"], 5.0)
			progress.discover("bath_ball"))
	room.bathtub.ball_dissolved.connect(func() -> void:
		if not progress._loading:
			SfxScript.play("plop")
			hud.show_message(MESSAGES["ball_dissolved"], 5.0)
			progress.discover("ball_dissolved")
			progress.add_note("ball_driver", "玉の中のドライバー", "入浴剤の玉は、お湯でだけ溶けた。中身はドライバーだった。", "手がかり"))
	room.shower_curtain.digits_revealed.connect(func() -> void:
		hud.show_message(MESSAGES["curtain_sprayed"], 5.0)
		progress.discover("curtain_digits")
		progress.add_note("curtain_digits", "カーテンの数字", "濡れたカーテンに数字が浮かんだ：『%s』。" % room.shower_curtain.DIGITS, "パスワード"))
	hud.restart_pressed.connect(_restart_fresh)
	_load_settings()
	room.apartment.intercom.front_door = room.front_door
	room.apartment.intercom.notice.connect(func(text: String) -> void: hud.show_message(text, 5.0))
	room.apartment.ufo_catcher.coin_check = spend_coin
	room.toilet.coin_taken.connect(add_coin)
	room.apartment.cellar.descend_requested.connect(_descend)
	room.apartment.basement.ascend_requested.connect(_ascend)
	room.apartment.cellar.stairs_revealed.connect(func() -> void:
		if not progress._loading:
			hud.show_message(MESSAGES["stairs_revealed"], 5.0)
			progress.discover("stairs"))
	room.apartment.ufo_catcher.prize_won.connect(_on_prize_won)
	room.apartment.star_figure_down.connect(_on_star_down)
	room.apartment.record_player.disc_set.connect(func() -> void:
		remove_item("record_disc")
		progress.discover("record_set"))
	fishing = FishingScript.new()
	fishing.name = "Fishing"
	room.add_child(fishing)
	fishing.player = player
	fishing.coin_caught.connect(func() -> void: add_coin(1))
	fishing.notice.connect(func(text: String) -> void: hud.show_message(text))
	hud.set_catch_text(fishing.collection_text())
	fishing.collection_changed.connect(hud.set_catch_text)
	fishing.story_next = Callable(self, "_story_catch_next")
	fishing.item_caught.connect(_on_story_caught)
	room.apartment.curtain_changed.connect(_on_curtain_changed)
	room.exterior.breaker.fuse_inserted.connect(_on_fuse_inserted)

	if _wants_title():
		_show_title()
	else:
		_begin_play()


## タイトル画面を出すか。実際に起動したときの最初の 1 回だけ（やり直しの再読み込み・テスト・撮影では出さない）。
## 環境変数 TOIRE_TITLE=1 で、テストでも出せる。TOIRE_NO_TITLE=1 で出さない。
func _wants_title() -> bool:
	if OS.get_environment("TOIRE_NO_TITLE") == "1":
		return false
	if OS.get_environment("TOIRE_TITLE") == "1":
		return not _title_seen
	return not _title_seen and DisplayServer.get_name() != "headless" and OS.get_environment("SHOT_DIR") == ""


func title_active() -> bool:
	return _title != null


func _show_title() -> void:
	_title = TitleScript.new()
	_title.name = "Title"
	_title.has_save = progress.has_save()
	_title.continue_note = progress.saved_chapter_name()
	_title.start_requested.connect(_on_title_start)
	_title.settings_requested.connect(func() -> void:
		_title.show_ui(false)
		hud.show_pause(true))
	_title.quit_requested.connect(func() -> void: get_tree().quit())
	add_child(_title)
	get_tree().paused = true
	player.controls_enabled = false
	hud.set_title_mode(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_title_start(continue_save: bool) -> void:
	if not continue_save:
		progress.delete_save()
	hud.set_fade_now(1.0)   # タイトルの暗がりのまま、ゲームの側へ（トイレの初期位置）
	_title.queue_free()
	_title = null
	_title_seen = true
	hud.set_title_mode(false)
	get_tree().paused = false
	player.controls_enabled = true
	_begin_play(not continue_save)
	hud.fade_to(0.0, 1.6)


## 遊びはじめ：視点を掴み、続きがあれば読み込み、最初の一言と操作のヒントを出す。
func _begin_play(with_opening := false) -> void:
	_title_seen = true
	_apply_preview()
	if OS.get_environment("TOIRE_YEN100") == "1":
		give_yen100()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if progress.load_game():
		hud.show_message("……前に来た、あの部屋だ。続きから。", 4.0, "voice")
	else:
		hud.show_message(MESSAGES["start"], 5.0)
		if with_opening:
			_opening_event()
	_count_examinable()
	var seen_cfg := ConfigFile.new()
	seen_cfg.load(SETTINGS_PATH)
	if not bool(seen_cfg.get_value("ui", "intro_seen", false)):
		hud.show_intro("移動：W A S D　視点：マウス　調べる：左クリック\n座る・入る：E　しゃがむ：C　メッセージの履歴：H\nノート：N　目の高さ：[ と ]　設定：Esc")
		seen_cfg.set_value("ui", "intro_seen", true)
		seen_cfg.save(SETTINGS_PATH)


func _process(_delta: float) -> void:
	if _title != null:
		return
	if not _ko_seen and not paused and ExteriorScript.in_balcony(player.global_position):
		var fwd: Vector3 = -player.camera.global_basis.z
		if fwd.x > 0.6 and fwd.y > -0.6:   # ベランダで、右手（東）を見た
			_ko_seen = true
			hud.show_message(MESSAGES["ko_line"], 5.0, "voice")
			progress.discover("ko_line")
			progress.add_note("ko_line", "KO線", "右手の遠くに高架の線路。電車がゆっくり走っている。", "手がかり")
	_update_lint(_delta)
	if not paused and not cleared and play_time >= _mutter_next and not reading and not mj_playing and not gaming and not peeping and not hiding_in_closet():
		_mutter_next = play_time + 150.0 + randf() * 90.0
		if _mutter_idle_i < StoryData.IDLE_MUTTERS.size():
			_mutter(StoryData.IDLE_MUTTERS[_mutter_idle_i])
			_mutter_idle_i += 1
	_update_torch_light(_delta)
	_update_scroll(_delta)
	var carried: String = room.apartment.cellar.carrying_name
	hud.set_carry("運んでいる：%s（冷蔵庫の中を狙って、左クリックで入れる）" % carried if not carried.is_empty() else "")
	if not paused and not cleared:
		play_time += _delta
		room.sky_clock.set_time(maxf(play_time, 620.0) if room.risen or room.rising else play_time)
	if not paused and room.exterior.blowgun_sign:
		room.exterior.set_blowgun_sign_visible(player.eye_height >= ExteriorScript.SIGN_MIN_EYE and ExteriorScript.in_balcony(player.global_position))
	_update_wall_hold(_delta)
	if _ufo_txn and not room.apartment.ufo_catcher.busy and not _prize_pending:
		_ufo_txn = false
		txn_end()
	room.washitsu.set_mouse_hole_visible(player.eye_height <= room.washitsu.MOUSE_EYE_MAX)
	_update_duct_sound()
	_check_neighbor_escape()
	if _hp_on and _hp_player and not _hp_player.playing and _hp_audio.ready():
		_start_headphones()
	room.apartment.record_player.holding = selected_item() == "record_disc"
	if mj_playing:
		hud.set_prompt("")
		_refresh_mahjong()
		return
	if peeping:
		hud.set_prompt("")
		return
	if gaming:
		hud.set_prompt("")
		var dir := 0.0
		if Input.is_action_pressed("move_forward"):
			dir -= 1.0
		if Input.is_action_pressed("move_back"):
			dir += 1.0
		room.apartment.tv_game.input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		return
	if paused or cleared or reading:
		hud.set_prompt("")
		hud.set_aim(false)
		return
	var focused := player.get_focused()
	hud.set_aim(focused != null and not _prompt_for(focused).is_empty())
	var parts := []
	var click := _prompt_for(focused)
	if not click.is_empty() and click != PROMPT_EXAMINE:   # 「左クリック：調べる」は出さない（照準の点だけで足りる）
		parts.append(click)
	var use := _use_prompt(focused)
	if not use.is_empty():
		parts.append(use)
	var action := _action_for(focused)
	if not action.is_empty():
		parts.append(ACTION_PROMPTS[action])
	hud.set_prompt("　／　".join(parts))


## 開発用：環境変数 TOIRE_PREVIEW=elevator / entrance で、まだ歩いて来られない場所（エレベーターの箱の中・1 階の入口）に立って始める。
func _apply_preview() -> void:
	match OS.get_environment("TOIRE_PREVIEW"):
		"elevator":
			player.global_position = room.PREVIEW_CAR_POS + Vector3(0.0, 0.05, -0.2)
			player.rotation.y = 0.0
		"entrance":
			player.global_position = room.ENTRANCE_POS + Vector3(0.0, 0.05, -2.4)
			player.rotation.y = PI


## ウィンドウが選ばれなくなったら自動で一時停止（ゲーム中に別のウィンドウへ移ったとき、勝手に進まないように）
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and _title == null and not paused and not cleared and not mj_playing and not gaming and not peeping:
		_pause()


func _unhandled_input(event: InputEvent) -> void:
	if _title != null:
		if event.is_action_pressed("pause") and hud._pause_menu.visible:
			get_viewport().set_input_as_handled()
			_resume()
		return
	# 推理ノート（N）。開いている間は Esc か N で閉じる
	if hud.is_notebook_open():
		if event.is_action_pressed("pause") or event.is_action_pressed("notebook"):
			get_viewport().set_input_as_handled()
			_close_notebook()
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hud.notebook_scroll(60.0)
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			hud.notebook_scroll(-60.0)
		elif event.is_action_pressed("move_back", true):
			hud.notebook_scroll(40.0)
		elif event.is_action_pressed("move_forward", true):
			hud.notebook_scroll(-40.0)
		return
	var free_to_use := not paused and not cleared and not mj_playing and not reading and not gaming and not peeping
	if event.is_action_pressed("notebook") and free_to_use and not hud.is_log_open():
		get_viewport().set_input_as_handled()
		hud.toggle_notebook(progress.chapter_lines(), progress.notes_text())
		player.controls_enabled = false   # 読んでいる間は、体が動かない
		return
	# 目の高さ（[ と ]）。設定を開かずに、いつでも変えられる
	if free_to_use and (event.is_action_pressed("eye_down") or event.is_action_pressed("eye_up")):
		get_viewport().set_input_as_handled()
		var step := EYE_STEP if event.is_action_pressed("eye_up") else -EYE_STEP
		var h := clampf(snappedf(player.eye_height + step, 0.01), PlayerScript.EYE_HEIGHT_MIN, PlayerScript.EYE_HEIGHT_MAX)
		_on_eye_height_changed(h)
		hud.set_eye_height_ui(player.eye_height)
		hud.show_height_toast(int(round(player.eye_height * 100.0)))
		return
	# メッセージの履歴（H）。開いている間は Esc か H で閉じる
	if hud.is_log_open():
		if event.is_action_pressed("pause") or event.is_action_pressed("message_log"):
			get_viewport().set_input_as_handled()
			hud.toggle_log()
		return
	if event.is_action_pressed("message_log") and not paused and not cleared and not mj_playing and not reading and not gaming and not peeping:
		get_viewport().set_input_as_handled()
		hud.toggle_log()
		return
	if mj_playing:
		_mahjong_input(event)
		return
	if peeping:
		# のぞき穴を見ている間：クリックか Esc でやめる
		if event.is_action_pressed("pause") or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			_close_peephole()
		return
	if gaming:
		# ゲーム中：E か Esc でやめる。ほかの操作は受け付けない
		if event.is_action_pressed("pause") or event.is_action_pressed("action"):
			get_viewport().set_input_as_handled()
			_stop_game()
		return
	if coding:
		if event is InputEventKey and event.pressed and not event.echo:
			var ke := event as InputEventKey
			get_viewport().set_input_as_handled()
			if ke.keycode == KEY_ESCAPE:
				_close_code(false)
			elif ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
				_close_code(true)
			elif ke.keycode == KEY_BACKSPACE:
				_code_buf = _code_buf.substr(0, maxi(0, _code_buf.length() - 1))
				_refresh_code()
			elif ke.unicode > 31 and _code_buf.length() < _code_len:
				var ch := char(ke.unicode)
				if (_code_digits and ch >= "0" and ch <= "9") or (not _code_digits and ch.to_upper() >= "A" and ch.to_upper() <= "Z"):
					_code_buf += ch.to_upper()
					SfxScript.play("click", 1.2)
					_refresh_code()
		return
	if reading:
		# 本を読んでいる間：左クリックで次のページ（最後は閉じる）、Esc で閉じる。ほかの操作は受け付けない
		if Engine.get_process_frames() == _reader_opened_frame:
			return
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_close_reader()
		elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_reader_page += 1
			SfxScript.play("page")
			if _reader_page >= _reader_pages.size():
				_close_reader()
			else:
				_show_reader_page()
		return
	if event.is_action_pressed("action"):
		get_viewport().set_input_as_handled()
		if not paused and not cleared:
			do_action()
		return
	if not paused and not cleared:
		if event.is_action_pressed("use_item"):
			get_viewport().set_input_as_handled()
			use_selected()
			return
		if event.is_action_pressed("item_1"):
			select_item(hud.inv_off + 0)
			return
		if event.is_action_pressed("item_2"):
			select_item(hud.inv_off + 1)
			return
		if event.is_action_pressed("item_3"):
			select_item(hud.inv_off + 2)
			return
		if event.is_action_pressed("item_4"):
			select_item(hud.inv_off + 3)
			return
		if event.is_action_pressed("item_5"):
			select_item(hud.inv_off + 4)
			return
		if event.is_action_pressed("item_6"):
			select_item(hud.inv_off + 5)
			return
		if event.is_action_pressed("item_7"):
			select_item(hud.inv_off + 6)
			return
		if event.is_action_pressed("item_8"):
			select_item(hud.inv_off + 7)
			return
		if event.is_action_pressed("inspect_item"):
			toggle_zoom()
			return
		if event.is_action_pressed("drop_item"):
			_drop_selected()
			return
		if event is InputEventMouseButton and event.pressed and inventory.size() > 0:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var step := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
				select_item(posmod((selected if selected >= 0 else 0) + step, inventory.size()))
				return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if cleared:
			return
		if paused:
			_resume()
		else:
			_pause()


# ---------------------------------------------------------------- 射的（コルク銃）

var _gun_cool := 0.0
var shots := 0


## コルク銃を撃つ。照準の先がフィギュアなら落ちる。外れたらコルクが飛んでいくだけ。連射はできない（0.4 秒）。
func _fire(target: Object) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _gun_cool:
		return
	_gun_cool = now + 0.4
	shots += 1
	SfxScript.play("shot")
	var from: Vector3 = player.camera.global_position + player.camera.global_transform.basis * Vector3(0.12, -0.1, -0.3)
	var to: Vector3 = player.camera.global_position - player.camera.global_transform.basis.z * 2.2
	if player.ray.is_colliding():
		to = player.ray.get_collision_point()
	var bullet := MeshKit.cylinder(room, 0.008, 0.02, from, MeshKit.mat("gun_cork", Color(0.75, 0.58, 0.38), 0.9), "Bullet")
	bullet.look_at_from_position(from, to)
	bullet.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := bullet.create_tween()
	tw.tween_property(bullet, "global_position", to, 0.12)
	tw.tween_callback(bullet.queue_free)
	var tid := String(target.get_meta("interact_id", "")) if target else ""
	if tid == "figure":
		var fig: Node3D = target.get_parent()
		if room.apartment.knock_figure(fig):
			hud.show_message("命中！ フィギュアが棚から落ちた！（%d 個目）" % room.apartment.figures_down)
		return
	if tid == "liquor_cellar" or tid.begins_with("liquor_"):
		if room.cellar_broken:
			hud.show_message("パンッ！ ……ガラスは、もう割れている。" + LIQUOR["broken"])
		else:
			var n: int = room.wine_cellar.add_crack(player.ray.get_collision_point() if player.ray.is_colliding() else target.global_position)
			room.cellar_cracks = room.wine_cellar.cracks
			hud.show_message("パンッ！ ガラスに、ヒビが入った。……割れはしない。" if n <= 1 else "パンッ！ ヒビが増えた。でも、割れる気配はない。")
		return
	hud.show_message("パンッ！ コルクが飛んでいって、はね返った。")


# ---------------------------------------------------------------- ゲームソフトの入れ替え

const GAME_NAMES := ["落ちものパズル（FALLING BLOCKS）", "レースゲーム（GRAND RACE）", "樽よけ・はしご登り（BARREL CLIMB）", "よけゲー（DODGE）", "ラベルのはがれたディスク"]


func _select_game(i: int) -> void:
	var apt = room.apartment
	apt.tv_game.select(i)
	SfxScript.play("click", 1.3)
	if i == 4:
		hud.show_message("ソフトを入れ替えた。ラベルがはがれたディスクだ。画面に「NO DISC」と出た……読み込めないらしい。")
	else:
		hud.show_message("ソフト『%s』を入れた。テレビ・ゲーム機・コントローラを調べると遊べる。" % GAME_NAMES[i])


# ---------------------------------------------------------------- 地下室

const BASEMENT_LETTER := [
	"拝啓\n\nこの手紙を読んでいるあなたは、きっと、冷蔵庫をきちんと片づけられる人です。\n\nだから、ここには何も置いていません。お宝も、出口も、ありません。",
	"あるのは、この手紙が一枚だけです。\n\n明日もあります。ごはんを食べて、よく寝てください。\n\n　　　　　　　　　　　　　　　　前の住人より",
]


## 貯蔵庫の穴から階段を降りて、地下室へ。穴の真上から階段の下までの経路を、滑らかに移る。
## 階段の昇り降り。穴が 0.6m と狭く、床下の頭上に余裕がないので、歩かずに画面を暗くして移す。
## 暗くなりきってから足元と向きを移し、そのあと明るくする（視点が跳ぶ瞬間は見えない）。
var _stairs_busy := false


func _stairs_travel(feet: Vector3, yaw: float, creak_pitch: float) -> void:
	if _stairs_busy or player.pose != PlayerScript.Pose.WALK and player.pose != PlayerScript.Pose.CROUCH:
		return
	_stairs_busy = true
	player.controls_enabled = false
	player.pose = PlayerScript.Pose.TRANSITION   # 移っている間は調べられない・動けない
	player.velocity = Vector3.ZERO
	SfxScript.play("creak", creak_pitch)
	var t := hud.fade_to(1.0, 0.45)
	t.tween_callback(func() -> void:
		player.global_position = feet
		player.velocity = Vector3.ZERO
		player.rotation.y = yaw
		player._pitch = -0.12
		player.camera.rotation.x = -0.12
		player.pose = PlayerScript.Pose.WALK)
	t.tween_interval(0.35)
	t.tween_callback(func() -> void:
		hud.fade_to(0.0, 0.5)
		player.controls_enabled = not mj_playing
		_stairs_busy = false)


func _descend() -> void:
	_stairs_travel(room.apartment.basement.FEET, PI * 0.5, 0.8)


func _ascend() -> void:
	_stairs_travel(room.apartment.basement.STAIR_EXIT, PI, 0.9)


# ---------------------------------------------------------------- 黒電話

## 黒電話：クリックのたびに、次の番号を回す（時報・天気予報・110・119・自宅・でたらめ）。
var phone_index := 0
const PHONE_CALLS := ["117", "177", "110", "119", "home", "0000"]


func _try_feed_lock(word: String) -> void:
	var aq = room.apartment.aquarium
	if word == aq.LOCK_WORD:
		aq.unlock_feed_box()
		progress.discover("feed_box_open")
		hud.show_message(STAGE5["feed_open"], 6.0)
	else:
		SfxScript.play("buzz", 0.8)
		hud.show_message(STAGE5["feed_wrong"])


func _phone_dial() -> void:
	_open_code("黒電話", "ダイヤルを回す。番号を入力してください。", 4, true, _phone_number)


func _phone_number(num: String) -> void:
	var which := num
	if num == room.shower_curtain.DIGITS:
		SfxScript.play("ring")
		progress.discover("phone_7305")
		if phone_coin_taken:
			hud.show_message(STAGE5["phone_empty"], 5.0)
			return
		phone_coin_taken = true
		hud.show_message(STAGE5["phone_coin"], 6.0)
		await get_tree().create_timer(1.5 / ride_speed).timeout
		add_coin(1)
		SfxScript.play("chime")
		return
	if not (num in PHONE_CALLS):
		which = "0000" if num != "0000" else which
		if num.length() < 3:
			which = "0000"
	match which:
		"117":
			var t: Dictionary = Time.get_datetime_dict_from_system()
			var h: int = t.hour
			SfxScript.play("beep", 1.0)
			hud.show_message("「1・1・7」と回した。『%s %d時%d分%d秒を、お知らせします。……ポッ、ポッ、ポッ、ポーン』" % ["午前" if h < 12 else "午後", h % 12, t.minute, t.second], 6.0)
		"177":
			SfxScript.play("static", 0.8)
			hud.show_message("「1・7・7」。『この地域の天気は……（ザザッ）……のち、晴れ……』。途中から声が雑音にのまれて消えた。")
		"110":
			SfxScript.play("click")
			hud.show_message("「1・1・0」。ダイヤルを回しかけて、手を止めた。いたずらはよくない。")
		"119":
			SfxScript.play("click")
			hud.show_message("「1・1・9」。回しかけて、やめた。火事でも救急でもない。")
		"home":
			SfxScript.play("ring")
			hud.show_message("自宅の番号を回してみた。リリリン、と鳴った。……すぐ後ろで、鳴った気がした。", 5.0)
		_:
			SfxScript.play("buzz", 0.8)
			hud.show_message("「0・0・0・0」。『おかけになった番号は、現在、使われておりません』")


# ---------------------------------------------------------------- のぞき穴

func _open_peephole() -> void:
	if peeping or reading or gaming or paused or cleared:
		return
	peeping = true
	player.controls_enabled = false
	hud.show_peephole(room.apartment.intercom.peephole_texture())
	var ic = room.apartment.intercom
	if ic.figure_visible():
		hud.show_message("のぞき穴の向こうに、人影が立っている。……動かない。", 4.0)
	else:
		hud.show_message("のぞき穴から、ぼんやりと廊下が見える。誰もいない。", 3.0)


func _close_peephole() -> void:
	if not peeping:
		return
	peeping = false
	hud.hide_peephole()
	player.controls_enabled = true


# ---------------------------------------------------------------- テレビゲーム

func _start_game() -> void:
	if gaming or reading or paused or cleared:
		return
	if player.pose != PlayerScript.Pose.WALK and player.pose != PlayerScript.Pose.CROUCH:
		return
	var apt = room.apartment
	if not apt.tv_on:
		apt.set_tv_on(true)
	if not apt.tv_game.playable():
		hud.show_message("画面に「NO DISC」と出る。ディスクが読み込めない。別のソフトに入れ替えよう。")
		return
	gaming = true
	player.controls_enabled = false
	player.look_at_point(apt.tv_screen_position())
	apt.tv_game.start()
	SfxScript.play("beep")
	hud.show_message(MESSAGES["tv_start"], 4.0)


func _stop_game() -> void:
	if not gaming:
		return
	gaming = false
	player.controls_enabled = true
	room.apartment.tv_game.stop()
	room.apartment.tv_game.input = Vector2.ZERO
	hud.show_message(MESSAGES["tv_stop"])


# ---------------------------------------------------------------- 一人麻雀

func _start_mahjong() -> void:
	if mj_playing or reading or paused or cleared or gaming or peeping:
		return
	if player.pose != PlayerScript.Pose.KOTATSU_IN:
		hud.show_message(MESSAGES["mj_need_kotatsu"])
		return
	mj_playing = true
	progress.discover("mahjong_play")
	player.controls_enabled = false
	if mahjong == null:
		mahjong = MahjongGame.new()
	mahjong.puzzle = inventory.has("mahjong_tiles")
	mahjong.start()
	mj_cursor = 13 if mahjong.state == "playing" else 0
	SfxScript.play("click")
	hud.show_message(MESSAGES["mj_start"], 3.0)
	_refresh_mahjong()
	_check_chuuren()


func _stop_mahjong() -> void:
	if not mj_playing:
		return
	mj_playing = false
	player.controls_enabled = true
	hud.hide_mahjong()
	hud.show_message(MESSAGES["mj_quit"])


func _refresh_mahjong() -> void:
	var help := "A／D：選ぶ　左クリック・Space：切る　E／Esc：やめる"
	if mahjong.state != "playing":
		help = "左クリック・Space：もう一局　E／Esc：やめる"
	hud.show_mahjong(mahjong, mj_cursor, help)


func _mahjong_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("action"):
		get_viewport().set_input_as_handled()
		_stop_mahjong()
		return
	var left: bool = event.is_action_pressed("move_left") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_LEFT)
	var right: bool = event.is_action_pressed("move_right") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_RIGHT)
	var confirm: bool = (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	if mahjong.state != "playing":
		if confirm:
			get_viewport().set_input_as_handled()
			mahjong.start()
			mj_cursor = 13 if mahjong.state == "playing" else 0
			SfxScript.play("click")
		return
	var count := 14 if mahjong.drawn >= 0 else 13
	if left:
		get_viewport().set_input_as_handled()
		mj_cursor = posmod(mj_cursor - 1, count)
		SfxScript.play("tick")
	elif right:
		get_viewport().set_input_as_handled()
		mj_cursor = posmod(mj_cursor + 1, count)
		SfxScript.play("tick")
	elif confirm:
		get_viewport().set_input_as_handled()
		mahjong.discard(mj_cursor)
		SfxScript.play("click")
		mj_cursor = 13 if mahjong.state == "playing" else 0
		if mahjong.state == "won":
			SfxScript.play("pop")
		_check_chuuren()


# ---------------------------------------------------------------- 本を読む

func _open_reader(title: String, pages: Array, cover: Texture2D, tint: Color) -> void:
	if reading or paused or cleared:
		return
	SfxScript.play("page")
	reading = true
	_reader_title = title
	_reader_pages = pages
	_reader_page = 0
	_reader_cover = cover
	_reader_tint = tint
	_reader_opened_frame = Engine.get_process_frames()
	player.controls_enabled = false
	_show_reader_page()


## 入力画面を開く。決定（Enter）で cb(入力文字列) を呼ぶ。
func _open_code(title: String, prompt: String, length: int, digits: bool, cb: Callable) -> void:
	if reading or coding or paused or cleared:
		return
	coding = true
	reading = true
	_code_title = title
	_code_prompt = prompt
	_code_len = length
	_code_digits = digits
	_code_cb = cb
	_code_buf = ""
	_reader_opened_frame = Engine.get_process_frames()
	player.controls_enabled = false
	_refresh_code()


func _refresh_code() -> void:
	hud.show_code(_code_title, _code_prompt, _code_buf, _code_len)


func _close_code(submit: bool) -> void:
	coding = false
	reading = false
	hud.hide_reader()
	player.controls_enabled = true
	if submit and not _code_buf.is_empty():
		_code_cb.call(_code_buf)


func _show_reader_page() -> void:
	hud.show_reader(_reader_title, _reader_pages[_reader_page], _reader_cover, _reader_tint, _reader_page, _reader_pages.size())


func _close_reader() -> void:
	reading = false
	hud.hide_reader()
	player.controls_enabled = true
	if _reader_after.is_valid():
		var after := _reader_after
		_reader_after = Callable()
		after.call()
	# 特定の短編集には、栞が挟まっている（最後のページまで読んだとき）
	if BOOKMARK_BOOKS.has(_reader_title) and _reader_page >= _reader_pages.size() - 1:
		var bm: String = BOOKMARK_BOOKS[_reader_title]
		if not inventory.has(bm) and not items_found.has(bm):
			_give_stage4(bm)
			hud.show_message(STAGE4["bookmark_found"] % ITEMS[bm].name, 5.0)


# ---------------------------------------------------------------- 姿勢（座る・浴槽）

## 今 E キーでできること（ACTION_PROMPTS のキー）。なければ空。
func _action_for(target: Object) -> String:
	match player.pose:
		PlayerScript.Pose.SEATED:
			return "stand_up"
		PlayerScript.Pose.IN_TUB:
			if room.bathtub.shower_held:
				return "shower_return"
			# 浴槽の中から換気口を狙うと「換気口へ入る」
			if target and String(target.get_meta("interact_id", "")) == "vent":
				return "vent_enter" if _tall_enough() else "vent_far"
			return "tub_exit"
		PlayerScript.Pose.TRANSITION:
			return ""
		PlayerScript.Pose.LYING:
			return "get_up"
		PlayerScript.Pose.KOTATSU_SEAT:
			return "kotatsu_stand"
		PlayerScript.Pose.CLOSET:
			return "closet_exit"
		PlayerScript.Pose.KOTATSU_IN:
			return "kotatsu_out"
		PlayerScript.Pose.DUCT:
			var p := player.global_position
			if Vector2(p.x - VENT_MOUTH.x, p.z - VENT_MOUTH.z).length() < DUCT_BACK_RANGE:
				return "duct_back"
			if p.z < ExteriorScript.DUCT_EXIT_EDGE_Z and p.x > ExteriorScript.DUCT_B.position.x:
				return "balcony_down" if room.exterior.ladder_down else "ladder_lower"
			return ""
		PlayerScript.Pose.LEAN:
			return "lean_back"
	if target == null:
		return ""
	var id := String(target.get_meta("interact_id", ""))
	if id == "vent" and _can_stretch_to_vent():
		return "vent_stretch"
	if id == "fish_spot" and player.pose == PlayerScript.Pose.WALK and ExteriorScript.in_balcony(player.global_position):
		return "lean_out"
	if id == "kotatsu" and player.pose == PlayerScript.Pose.WALK:
		return "kotatsu_sit"
	if id == "ladder_placed" and player.pose == PlayerScript.Pose.WALK:
		return "ladder_down" if player.global_position.y > 1.2 else "ladder_up"
	if (id == "fusuma" or id == "fusuma_r") and player.pose == PlayerScript.Pose.WALK:
		return "closet_enter"
	if id == "bed" and player.pose == PlayerScript.Pose.WALK:
		return "sleep"
	if id in ["toilet", "toilet_seat", "toilet_lid"] and room.toilet.can_sit():
		return "sit"
	if id in ["bathtub", "bath_plug"]:
		return "tub_enter"
	return ""


## E キーの動作。座る／立つ／浴槽に入る／出る。
func do_action() -> void:
	var action := _action_for(player.get_focused(true))
	match action:
		"sit":
			room.toilet.occupied = true
			player.enter_fixed(PlayerScript.Pose.SEATED, _up(SEAT_FEET), SEAT_YAW, SEAT_EYE)
		"kotatsu_sit":
			if not room.power_on:
				hud.show_message(POWER_DEAD["kotatsu"])
				return
			SfxScript.play("rustle")
			kotatsu_seat = KotatsuScript.nearest_seat(player.global_position)
			var seat: Dictionary = KotatsuScript.SEATS[kotatsu_seat]
			player.enter_fixed(PlayerScript.Pose.KOTATSU_SEAT, seat.feet, seat.yaw, KotatsuScript.EYE_SEATED)
		"sleep":
			if not room.power_on:
				hud.show_message(POWER_DEAD["bed"])
				return
			SfxScript.play("rustle")
			player.enter_fixed(PlayerScript.Pose.LYING, BED_FEET, BED_YAW, BED_EYE)
			progress.discover("bed_sleep")
			hud.show_message(MESSAGES["sleep_in"])
		"get_up":
			if player.leave_fixed(BED_EXITS):
				SfxScript.play("rustle")
				hud.show_message(MESSAGES["sleep_out"])
			else:
				hud.show_message(MESSAGES["no_way_out"])
		"kotatsu_stand":
			if not player.leave_fixed(KotatsuScript.SEATS[kotatsu_seat].exits):
				hud.show_message(MESSAGES["no_way_out"])
		"ladder_up":
			_climb_ladder(true)
		"ladder_down":
			_climb_ladder(false)
		"closet_enter":
			_enter_closet()
		"closet_exit":
			_exit_closet()
		"kotatsu_out":
			var seat2: Dictionary = KotatsuScript.SEATS[kotatsu_seat]
			room.apartment.kotatsu.set_solid(true)
			SfxScript.play("rustle")
			player.move_to(PlayerScript.Pose.KOTATSU_SEAT, seat2.feet, seat2.yaw, KotatsuScript.EYE_SEATED)
		"stand_up":
			var seat_exits: Array = []
			for sx in SEAT_EXITS:
				seat_exits.append(_up(sx))
			if player.leave_fixed(seat_exits):
				room.toilet.occupied = false
				if not room.toilet_panel.mode.is_empty():
					hud.show_message(MESSAGES["washlet_stood_up"])
				room.toilet_panel.stop()   # 立つと操作パネルは止まる
			else:
				hud.show_message(MESSAGES["no_way_out"])
		"tub_enter":
			var feet: Vector3 = _tub_feet()
			if player.is_space_free(feet, TUB_BODY_HEIGHT):
				player.enter_fixed(PlayerScript.Pose.IN_TUB, feet, TUB_YAW, _tub_eye())
		"shower_return":
			room.bathtub.release_shower()
			hud.show_message(MESSAGES["shower_back"])
		"tub_exit":
			var exits: Array = []
			for ex in TUB_EXITS:
				exits.append(_up(ex))
			if not player.leave_fixed(exits):
				hud.show_message(MESSAGES["no_way_out"])
		"vent_enter":
			room.open_vent()
			player.move_to(PlayerScript.Pose.DUCT, _up(ExteriorScript.DUCT_START), DUCT_YAW, PlayerScript.DUCT_EYE_HEIGHT,
					[_up(VENT_BELOW), _up(VENT_MOUTH)], true, PlayerScript.DUCT_BODY_HEIGHT, PlayerScript.DUCT_BODY_RADIUS)
		"duct_back":
			player.move_to(PlayerScript.Pose.IN_TUB, _tub_feet(), TUB_YAW, _tub_eye(), [_up(VENT_MOUTH), _up(VENT_BELOW)])
		"ladder_lower":
			room.exterior.lower_ladder(ExteriorScript.DUCT_FLOOR + room.rise_offset)
			SfxScript.play("creak", 0.7)
			hud.show_message(MESSAGES["ladder_lowered"])
			progress.discover("ladder")
			progress.add_note("ladder", "ボロボロのはしご", "ダクトの出口から、ベランダへ下ろせる。錆びて、段が抜けている。", "手がかり")
		"lean_out":
			var lx := clampf(player.global_position.x, ExteriorScript.BALCONY.position.x + 0.3, ExteriorScript.BALCONY.end.x - 0.3)
			_lean_x = lx
			player.move_to(PlayerScript.Pose.LEAN, Vector3(lx, 0.0, ExteriorScript.BALCONY.position.z - 0.32), 0.0, 1.3)
			hud.show_message(MESSAGES["lean_out"])
			progress.discover("lean_out")
		"lean_back":
			var back := [Vector3(_lean_x, 0.0, -1.75), Vector3(_lean_x, 0.0, -1.65), Vector3(2.4, 0.0, -1.7)]
			if not player.leave_fixed(back):
				hud.show_message(MESSAGES["no_way_out"])
		"vent_far":
			hud.show_message(MESSAGES["vent_far"])
			progress.add_note("vent_far", "天井の換気口", "高くて手が届かない。（設定で背を最大まで伸ばせば、背伸びで届く？）", "手がかり")
		"vent_stretch":
			hud.show_message(MESSAGES["vent_stretch"])
			progress.discover("vent_stretch")
			room.open_vent()
			player.move_to(PlayerScript.Pose.DUCT, _up(ExteriorScript.DUCT_START), DUCT_YAW, PlayerScript.DUCT_EYE_HEIGHT,
					[_up(VENT_BELOW), _up(VENT_MOUTH)], true, PlayerScript.DUCT_BODY_HEIGHT, PlayerScript.DUCT_BODY_RADIUS)
		"balcony_down":
			if player.leave_fixed(BALCONY_LANDINGS, [_up(DUCT_EXIT_MOUTH)]):
				route_duct = true
			else:
				hud.show_message(MESSAGES["no_way_out"])


# ---------------------------------------------------------------- 調べる

func _prompt_for(target: Object) -> String:
	if target == null:
		return ""
	var id := String(target.get_meta("interact_id", ""))
	var fixture: Object = target.get_meta("fixture") if target.has_meta("fixture") else null
	if id == "bath_shower" and player.pose == PlayerScript.Pose.IN_TUB and not room.bathtub.shower_held:
		return "左クリック：シャワーを手に取る"
	if id == "bath_plug" and room.bathtub.lid == "coin":
		return PROMPTS["coin10_take"]
	if fixture:
		# リモコン・操作パネルは「ボタン名：状態｜クリックしたときの動作」をそのまま返す
		if fixture.has_method("get_prompt_text"):
			return fixture.get_prompt_text(id)
		return PROMPTS.get(fixture.get_prompt(id), "")
	if id.begins_with("game_case_"):
		return PROMPTS["game_case"]
	match id:
		"":
			return ""
		"driver", "tub_driver", "tub_lint", "sink_sinker", "sink_soap", "mirror_paper", "spare_roll", "bath_powder", "fishing_rod", "cork_gun", "mahjong", "record_disc", "wood_stick":
			return PROMPT_PICKUP
		"towel_scratch":
			return PROMPT_PICKUP if room.towel.has_coin else PROMPT_EXAMINE
		"inspect_lever":
			return "左クリック：レバーを引く" if not room.risen and not room.rising else PROMPT_EXAMINE
		"door":
			return PROMPT_EXAMINE
		"kotatsu":
			return PROMPTS["kotatsu_enter"] if player.pose == PlayerScript.Pose.KOTATSU_SEAT else PROMPT_EXAMINE
		"tv_play":
			return PROMPTS["tv_play"]
		"cards":
			return PROMPTS["cards_draw"]
		"dice":
			return PROMPTS["dice_roll"]
		"tv_remote":
			return PROMPTS["tv_remote"]
		"door_knob", "fuse", "hand_mirror", "pickaxe", "crystal", "ladder_prop", "washitsu_coin", "heirloom_photo", "lighter", "rice_pack", "shot_coin", "bad_book", "card_pick_0", "card_pick_1", "card_pick_2", "card_pick_3", "aq_coin", "dish_core", "dart_coin", "headphones", "placed_item":
			return PROMPT_PICKUP
		"balcony_wall_w", "balcony_wall_e", "granny_chest":
			return PROMPT_EXAMINE
		"feed_box":
			return PROMPT_EXAMINE
		"closet_safe":
			return PROMPT_EXAMINE
		"kotatsu_hole":
			return "左クリック：穴へ進む"
		"washitsu_hole":
			return "左クリック：穴から、こたつの中へ戻る"
		"elevator":
			return "左クリック：エレベーターに乗る"
		"vending":
			return "左クリック：自動販売機を使う"
		_:
			return PROMPT_EXAMINE


## 毛だまり：浴槽の中でシャワーを浴びる／水に浸かると取れて、排水口の近くに流れ着く。
func _update_lint(delta: float) -> void:
	if room.bathtub.shower_held and player.pose != PlayerScript.Pose.IN_TUB and player.pose != PlayerScript.Pose.TRANSITION:
		room.bathtub.release_shower()
	if paused or cleared or not has_lint:
		return
	if player.pose != PlayerScript.Pose.IN_TUB:
		return
	if not _lint_hinted:
		_lint_hinted = true
		hud.show_message(MESSAGES["lint_hint"])
	var tub = room.bathtub
	if tub.shower.is_on or tub.level >= 0.25:
		_lint_wash += delta
		if _lint_wash >= 2.5:
			has_lint = false
			tub.drop_lint()
			hud.show_message(MESSAGES["lint_washed"], 5.0)
			progress.discover("lint_washed")


func _on_interact_requested(target: Object) -> void:
	if paused or cleared or reading or target == null:
		return
	var id := String(target.get_meta("interact_id", ""))
	var fixture: Object = target.get_meta("fixture") if target.has_meta("fixture") else null
	if id == "paper_holder":
		match room.supplies.pull_paper():
			"first":
				hud.show_message(MESSAGES["paper_holder"])
				return
			"pull":
				SfxScript.play("rustle")
				hud.show_message(STAGE5["paper_pull"])
				return
			"out":
				SfxScript.play("rustle")
				hud.show_message(STAGE5["paper_out"], 5.0)
				return
			"core":
				_give_stage5("tp_core2")
				hud.show_message(STAGE5["paper_core2"], 4.0)
				return
	if not id.is_empty():
		examined[id] = true
		progress.note_activity()
		progress.discover(id)
		_maybe_find_memo(id)
		if NOTE_CLUES.has(id):
			var clue: Array = NOTE_CLUES[id]
			progress.add_note(id, clue[0], clue[1], clue[2])
	# 床下の食べ物を持っているとき、開けた冷蔵室の中を狙うと、棚に入れる（全部入れると階段が現れる）
	var cellar_c = room.apartment.cellar
	if not cellar_c.carrying_id.is_empty() and id == "fridge_inside":
		var name_c: String = cellar_c.carrying_name
		if room.apartment.kitchen.put_food(cellar_c.carrying_id):
			var left_after: int = cellar_c.FOODS.size() - cellar_c.stored.size() - 1
			hud.show_message(MESSAGES["fridge_put"].replace("{food}", name_c).replace("{left}", str(left_after)))
			cellar_c.food_stored()
			progress.save()
		return
	if not room.power_on and (POWER_DEAD.has(id) or id.begins_with("game_case_") or id.begins_with("ufo_")):
		hud.show_message(POWER_DEAD.get(id, STAGE3["no_power"]))
		return
	if id == "window" and room.apartment.window_locked and player.global_position.z < ExteriorScript.FACADE_Z:
		hud.show_message(STAGE3["window_locked"])
		progress.add_note("window_locked", "ベランダの窓", "鍵がかかっている。部屋の鍵がいる。", "手がかり")
		return
	if id == "bath_shower" and player.pose == PlayerScript.Pose.IN_TUB:
		room.bathtub.hold_shower(player.camera)
		hud.show_message(MESSAGES["shower_hold"])
		return
	if id == "sink_plug":
		if room.sink.plug_in:
			room.sink.set_plug(false)
			SfxScript.play("click")
			_give_coin10()
			hud.show_message(MESSAGES["coin_taken_back"])
		else:
			hud.show_message(MESSAGES["sink_no_plug"])
		return
	if id == "bath_plug" and room.bathtub.lid == "coin":
		room.bathtub.take_coin_lid()
		SfxScript.play("click")
		_give_coin10()
		hud.show_message(MESSAGES["coin_taken_back"])
		return
	if fixture:
		# 便器・浴槽・蛇口など状態を持つ設備は、その設備が操作し、表示する説明のキーを返す
		var key: String = fixture.interact(id)
		if not key.is_empty():
			var text: String = MESSAGES[key] if MESSAGES.has(key) else (STAGE3[key] if STAGE3.has(key) else STAGE5[key])
			if fixture.has_method("format_message"):
				text = fixture.format_message(key, text)
			hud.show_message(text)
		return
	if id.begins_with("game_case_"):
		_select_game(int(id.substr(10)))
		return
	if not fixture and INTERACT_SFX.has(id):
		SfxScript.play(INTERACT_SFX[id])
	match id:
		"sink", "vent", "poster", "bath_bucket", \
		"toilet_cleaner", "plunger", "toilet_brush", "vent_sticker", "shampoo", "rinse", "razor", \
		"face_wash", "toner", "cotton_swabs", "tub_note", "shelf_note", "tank_note", \
		"kitchen_sink", "kitchen_stove", "fridge", "guitar", "taxidermy", "phone_mobile", \
		"life_paper_02", "life_paper_07", "bed", "microwave", "game_cover_1", "game_cover_2", "game_cover_3", "game_cover_4", "record_jacket_1", "record_jacket_2", "record_jacket_3", "record_jacket_4", "game_cover_5", "game_cover_6", "game_cover_7", "book_new_1", "book_new_2", "book_new_3", "book_new_4", "book_new_5", "book_new_6", "book_new_7", "book_new_8", "rug", "card_box", "magazines", "teddy", "clothes", "dumbbell", "bottle", "bag", "shoes", "toilet_slippers", "standee":
			hud.show_message(MESSAGES[id])
		"phone_black":
			_phone_dial()
		"liquor_cellar", "liquor_1", "liquor_2", "liquor_3", "liquor_4", "liquor_5", "liquor_6":
			# 割れたあとは、何を調べても同じ（ガラスは割れても、お酒は飲めない）
			hud.show_message(LIQUOR["broken"] if room.cellar_broken else LIQUOR[id])
		"ornament":
			hud.show_message(LIQUOR[id])
		"hand_mirror":
			if inventory.has("hand_mirror") or items_found.has("hand_mirror"):
				return
			if not room.mirror_cabinet.is_open:
				hud.show_message(STAGE4["mirror_stuck"], 5.0)
				return
			_give_stage4("hand_mirror")
			room.mirror_cabinet.take_hand_mirror()
			hud.show_message(STAGE4["mirror_pickup"])
		"gem":
			hud.show_message(STAGE4["gem_look_mirror"] if inventory.has("hand_mirror") else STAGE4["gem_look"])
		"pickaxe":
			if inventory.has("pickaxe") or room.apartment.pickaxe_taken:
				return
			_give_stage4("pickaxe")
			room.apartment.take_pickaxe()
			hud.show_message(STAGE4["pickaxe_pickup"])
		"crystal":
			if inventory.has("crystal") or room.apartment.crystal_taken:
				return
			_give_stage4("crystal")
			room.apartment.take_crystal()
			hud.show_message(STAGE4["crystal_pickup"])
		"kotatsu_wall":
			hud.show_message(STAGE4["wall_look"] if not inventory.has("pickaxe") else STAGE4["wall_hard"])
		"kotatsu_hole":
			_enter_washitsu()
		"washitsu_hole":
			_leave_washitsu()
		"scroll":
			_look_scroll()
		"heirloom":
			if room.washitsu.heirloom_open:
				hud.show_message(STAGE4["heirloom_done"])
			else:
				hud.show_message(STAGE4["heirloom_look"] + "（%d / 3）" % room.washitsu.slots_filled)
		"heirloom_photo":
			_take_photo()
		"grandma_photo":
			hud.show_message(STAGE4["grandma"])
		"kamidana":
			hud.show_message(STAGE4["kamidana"])
		"ranma":
			hud.show_message(STAGE4["ranma_high"] if player.eye_height >= 1.65 else STAGE4["ranma_low"])
		"town_map":
			hud.show_message(STAGE4["town_map"])
		"mouse_hole":
			hud.show_message(STAGE4["mouse_hole"])
		"ladder_prop":
			if inventory.has("wood_ladder") or room.washitsu.ladder_taken:
				return
			_give_stage4("wood_ladder")
			room.washitsu.take_ladder()
			hud.show_message(STAGE4["ladder_pickup"])
		"washitsu_coin":
			if room.washitsu.coin_taken:
				return
			room.washitsu.take_coin()
			add_coin(1)
			progress.discover("washitsu_coin")
			hud.show_message(STAGE4["coin_pickup"], 5.0)
		"rice_pack":
			if inventory.has("rice_pack") or room.apartment.kitchen.rice_taken:
				return
			_give_stage4("rice_pack")
			room.apartment.kitchen.take_rice()
			hud.show_message(STAGE4["rice_pickup"])
		"lighter":
			if inventory.has("lighter") or room.exterior.breaker.lighter_taken:
				return
			_give_stage4("lighter")
			room.exterior.breaker.take_lighter()
			hud.show_message(STAGE4["lighter_pickup"])
		"door_knob":
			if inventory.has("door_knob") or room.knob_taken:
				return
			_give_stage3("door_knob")
			room.take_door_knob()
			hud.show_message(STAGE3["knob_pickup"])
		"fuse":
			if inventory.has("fuse") or room.fuse_taken:
				return
			_give_stage3("fuse")
			room.take_fuse()
			hud.show_message(STAGE3["fuse_pickup"])
		"elevator":
			_ride_elevator()
		"vending":
			_use_vending()
		"cork_gun":
			if inventory.has("cork_gun"):
				return
			_item_models["cork_gun"] = CorkGunScript.zoom_model()
			room.apartment.kitchen.remove_gun()
			add_item("cork_gun")
			hud.show_message(MESSAGES["cork_gun"])
		"mahjong":
			if inventory.has("mahjong"):
				return
			_item_models["mahjong"] = ClosetScriptRef.mahjong_zoom_model()
			room.apartment.closet.take_mahjong()
			add_item("mahjong")
			hud.show_message(MESSAGES["mahjong"])
		"record_disc":
			if inventory.has("record_disc"):
				return
			_item_models["record_disc"] = RecordPlayerRef.zoom_model()
			room.apartment.record_player.take_display()
			add_item("record_disc")
			hud.show_message(MESSAGES["record_disc"])
		"card_pick_0", "card_pick_1", "card_pick_2", "card_pick_3":
			var ck := int(id.substr(10))
			if ck in cards_taken:
				return
			cards_taken.append(ck)
			_give_stage5("blank_card_%d" % ck)
			(target.get_parent() as Node3D).visible = false
			(target as Area3D).collision_layer = 0
			hud.show_message(STAGE5["card_pick"], 5.0)
		"feed_box":
			var aq = room.apartment.aquarium
			if aq.feed_unlocked:
				hud.show_message(STAGE5["feed_opened"])
			else:
				hud.show_message(STAGE5["feed_look"], 5.0)
				_open_code("餌箱の鍵", "5 文字のアルファベットを合わせる。", 5, false, _try_feed_lock)
		"aq_coin":
			var aq2 = room.apartment.aquarium
			if aq2.coin_taken:
				return
			aq2.take_coin()
			add_coin(1)
			SfxScript.play("chime")
			hud.show_message(STAGE5["aq_coin_msg"], 5.0)
		"diary_mine":
			_read_diary(StoryData.MY_DIARY, "diary_mine", "自分の日記", "自分の字で、見覚えのない「コタニ」という人のことが書いてある。最後は、破りとられている。")
		"diary_grandma":
			_read_diary(StoryData.GRANDMA_DIARY, "diary_grandma", "おばあちゃんの日記", "おばあちゃんは、出ていくことを決めた。理由は書いていない。最後に、顔を合わせたかったらしい。")
		"dart_coin":
			if room.exterior.dart_coin_taken:
				return
			room.exterior.take_dart_coin()
			add_coin(1)
			SfxScript.play("chime")
			hud.show_message(STAGE5["dart_coin_get"], 5.0)
		"balcony_wall_w", "balcony_wall_e":
			hud.show_message(STAGE5["wall_%s_look" % id.right(1)], 5.0)
		"granny_chest":
			_open_chest()
		"headphones":
			if inventory.has("headphones") or items_found.has("headphones"):
				return
			room.apartment.kotatsu.take_headphones()
			_give_stage5("headphones")
			_hp_audio.generate_async()
			hud.show_message(STAGE5["hp_pick"], 5.0)
		"placed_item":
			_pickup_placed(target)
		"dish_core":
			if room.supplies.dish_core_taken:
				return
			room.supplies.take_dish_core()
			_give_stage5("tp_core")
			hud.show_message(STAGE5["dish_core_pick"], 4.0)
		"ceiling_dot":
			hud.show_message(STAGE5["ceiling_dot"], 5.0)
		"closet_safe":
			if room.apartment.closet.safe_open:
				hud.show_message(STAGE5["safe_empty"] if safe_list_taken else STAGE5["safe_open"])
			else:
				hud.show_message(STAGE5["safe_look"])
		"bad_book":
			if inventory.has("bad_book") or inventory.has("bad_book_wet") or room.apartment.bad_book_taken:
				return
			_give_stage5("bad_book")
			room.apartment.take_bad_book()
			hud.show_message(STAGE5["bad_book_pickup"], 5.0)
		"shot_coin":
			if shot_coin_taken:
				return
			shot_coin_taken = true
			if shot_coin_node:
				shot_coin_node.queue_free()
				shot_coin_node = null
			add_coin(1)
			progress.discover("shot_coin")
			hud.show_message(STAGE5["shot_coin"], 5.0)
		"figure":
			if selected_item() == "cork_gun":
				_fire(target)
			else:
				hud.show_message(MESSAGES["figure"])
		"basement_letter":
			_open_reader("手紙", BASEMENT_LETTER, null, Color(0.95, 0.9, 0.78))
		"peephole":
			_open_peephole()
		"mail_catcher":
			hud.show_message("ミニポストの受け箱に、チラシが数枚。それと、宛名のない封筒が一通。" if room.apartment.intercom.rang else "ミニポストの受け箱に、ピザ屋と引っ越し屋のチラシが数枚。")
		"calendar":
			hud.show_message("壁掛けカレンダー。今日は%s。……赤い丸のほかに、予定は何も書いていない。" % room.apartment.calendar.date_text())
		"wall_clock":
			hud.show_message(MESSAGES["wall_clock"].replace("{time}", room.apartment.wall_clock.time_text()))
		"tissue":
			tissue_pulled += 1
			var left := maxi(0, TISSUE_SHEETS - tissue_pulled)
			hud.show_message("ティッシュを一枚引き出した。残り%d枚。" % left if left > 0 else "ティッシュは空っぽだ。箱を振ってもなにも出ない。")
		"cup":
			if play_time < 150.0:
				hud.show_message("湯のみ。湯気が立っている。まだ熱い。")
			elif play_time < 600.0:
				hud.show_message("湯のみ。お茶はぬるくなってきた。")
			else:
				hud.show_message("湯のみ。お茶はすっかり冷めている。")
		"cards":
			var card := SmallPropsScript.draw_card(_rng)
			hud.show_message("トランプを一枚めくった。……%s。" % card)
			hud.show_card(SmallPropsScript.last_card)
		"dice":
			hud.show_message("サイコロを振った。%d と %d。" % [_rng.randi_range(1, 6), _rng.randi_range(1, 6)])
		"tv_remote":
			room.apartment.set_tv_on(not room.apartment.tv_on)
			hud.show_message(MESSAGES["tv_on"] if room.apartment.tv_on else MESSAGES["tv_off"])
		"tv_play":
			_start_game()
		"towel_scratch":
			if room.towel.has_coin:
				room.towel.take_coin()
				_give_coin10()
				hud.show_message(MESSAGES["coin10_pickup"])
				progress.discover("ten_yen")
			else:
				hud.show_message(MESSAGES["towel_scratch"])
		"sink_soap":
			if inventory.has("soap") or room.sink.soap_taken:
				return
			room.sink.take_soap()
			_item_models["soap"] = SinkRef.soap_model()
			add_item("soap")
			hud.show_message(MESSAGES["soap_pickup"])
			progress.discover("soap")
		"sink_sinker":
			if inventory.has("sinker"):
				return
			room.sink.take_sinker()
			_item_models["sinker"] = SinkRef.sinker_model()
			add_item("sinker")
			hud.show_message(MESSAGES["sinker_pickup"])
			progress.discover("sinker")
		"tub_driver":
			if has_driver:
				return
			has_driver = true
			room.bathtub.take_driver()
			_item_models["driver"] = room.bathtub.get_node("TubDriver/Visual").duplicate()
			add_item("driver")
			hud.show_message(MESSAGES["tub_driver_pickup"])
			progress.discover("driver")
		"tub_lint":
			if inventory.has("lint"):
				return
			room.bathtub.take_lint()
			var lm := Node3D.new()
			for off in [Vector3.ZERO, Vector3(0.012, -0.004, 0.008), Vector3(-0.01, -0.005, 0.01)]:
				MeshKit.sphere(lm, 0.02, off, MeshKit.mat("lint_zoom", Color(0.55, 0.52, 0.5), 0.95))
			_item_models["lint"] = lm
			add_item("lint")
			hud.show_message(MESSAGES["lint_pickup"])
			progress.discover("lint")
		"mirror_paper":
			if inventory.has("paper"):
				return
			room.take_paper()
			_item_models["paper"] = RoomScript.paper_model(true)
			add_item("paper")
			hud.show_message(MESSAGES["paper_pickup"])
			progress.add_note("paper_mirror", "壁の鏡文字のメモ", "文字がひっくり返っている。鏡にかざせば読めそうだ。", "手がかり")
		"driver":
			if has_driver:
				return
			has_driver = true
			_item_models["driver"] = room.driver_node.get_node("Visual").duplicate()
			room.remove_driver()
			add_item("driver")
			hud.show_message(MESSAGES["driver"])
		"fishing_rod":
			if inventory.has("fishing_rod"):
				return
			_item_models["fishing_rod"] = FishingScript.zoom_model()
			fishing.has_rod = true
			fishing.remove_prop()
			add_item("fishing_rod")
			hud.show_message(MESSAGES["fishing_rod"])
		"spare_roll":
			if inventory.has("spare_roll") or room.supplies.spare_roll_taken:
				return
			_item_models["spare_roll"] = _model_without_areas(room.supplies.get_node("SupplyShelf/SpareRoll"))
			room.supplies.take_spare_roll()
			add_item("spare_roll")
			hud.show_message(MESSAGES["spare_roll_pickup"])
		"bath_powder":
			if inventory.has("bath_powder") or room.bath_powder_taken:
				return
			_item_models["bath_powder"] = room.get_node("BathPowder/Visual").duplicate()
			room.take_bath_powder()
			add_item("bath_powder")
			hud.show_message(MESSAGES["bath_powder_pickup"])
		"bath_bucket_disabled":
			if inventory.has("bucket") or room.bucket_taken or room.bucket_in_tub:
				return
			_item_models["bucket"] = _bucket_model()
			room.take_bucket()
			add_item("bucket")
			hud.show_message(MESSAGES["bucket_pick"])
			progress.add_note("bucket", "風呂桶", "大きめの風呂桶。逆さにすれば、足場になりそうだ。", "手がかり")
		"inspect_lever":
			_pull_lever()
		"wood_stick":
			if inventory.has("wood_stick"):
				return
			_item_models["wood_stick"] = _wood_stick_model()
			room.take_wood_stick()
			add_item("wood_stick")
			hud.show_message(MESSAGES["wood_stick"])
		"fuse_hatch":
			hud.show_message(MESSAGES["fuse_hatch"])
			progress.add_note("fuse_hatch", "柱の小さな扉", "ノブのない丸い穴。ドアノブがあれば、開けられそうだ。", "手がかり")
		"kotatsu":
			match player.pose:
				PlayerScript.Pose.KOTATSU_SEAT:
					var seat3: Dictionary = KotatsuScript.SEATS[kotatsu_seat]
					room.apartment.kotatsu.set_solid(false)   # 中を這って動けるように
					SfxScript.play("rustle")
					player.move_to(PlayerScript.Pose.KOTATSU_IN, seat3.inside, seat3.yaw, KotatsuScript.EYE_INSIDE, [], true, PlayerScript.KOTATSU_BODY_HEIGHT, PlayerScript.KOTATSU_BODY_RADIUS)
					hud.show_message(MESSAGES["kotatsu_inside"])
					progress.discover("kotatsu_in")
				PlayerScript.Pose.KOTATSU_IN:
					hud.show_message(MESSAGES["kotatsu_inside"])
				_:
					hud.show_message(MESSAGES["kotatsu_look"])
		"door":
			if door_open:
				return
			if not has_driver:
				room.rattle_door()
			hud.show_message(MESSAGES["door_loose"] if has_driver else MESSAGES["door_locked"])


# ---------------------------------------------------------------- 点検レバー・浴室がせり上がる

## 鏡の奥のレバーを引く。0.7 秒あとに、浴室が上がりはじめる（ゴゴゴ）。引いたあとは固まって動かない。
func _pull_lever() -> void:
	if room.risen or room.rising or _lever_busy:
		hud.show_message(MESSAGES["lever_stuck"])
		return
	_lever_busy = true
	progress.discover("inspect_lever")
	room.mirror_cabinet.pull_lever_visual()
	SfxScript.play("clunk", 0.8)
	hud.show_message(MESSAGES["lever_pull"], 4.0)
	progress.add_note("inspect_lever", "点検レバー", "鏡の奥の赤いレバー。引いたら、浴室ごと上がった。もう戻らない。", "手がかり")
	await get_tree().create_timer(0.7).timeout
	room.rise_unit(player)


## 浴槽に入ったときの足元（風呂桶が逆さに置いてあれば、その上）と、目の高さ（桶の上では立った高さ）。
func _tub_feet() -> Vector3:
	return room.bathtub.to_global(TUB_FEET_LOCAL) + Vector3(0.0, room.BUCKET_H if room.bucket_in_tub else 0.0, 0.0)


func _tub_eye() -> float:
	return player.eye_height - 0.05 if room.bucket_in_tub else TUB_EYE


## 背が最大（170 cm）のとき、換気口の近くで、床からの背伸びで届く（小ネタ）。
func _tall_enough() -> bool:
	return player.eye_height >= PlayerScript.EYE_HEIGHT_MAX - 0.001


func _can_stretch_to_vent() -> bool:
	if player.pose != PlayerScript.Pose.WALK or not _tall_enough():
		return false
	var p := player.global_position
	return Vector2(p.x - VENT_BELOW.x, p.z - VENT_BELOW.z).length() < 1.5


## 浴室と換気ダクトの座標（VENT_BELOW など）に、浴室の上昇量を足す。
func _up(v: Vector3) -> Vector3:
	return v + Vector3(0.0, room.rise_offset, 0.0)


func _on_unit_risen() -> void:
	progress.set_chapter(1)
	progress.discover("unit_rise")
	hud.show_message("扉が壊れた。外は暗く、ホールの床が、ずいぶん下に見える。……出られそうにない。", 6.0, "voice")
	progress.add_note("rise_view", "上がった浴室", "扉は壊れた。外のホールは暗く、床がずっと下だ。出口は、天井の換気口だけ。", "手がかり")


static func _bucket_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.12, 0.17, Vector3.ZERO, MeshKit.mat("bucket", Color(0.62, 0.78, 0.86), 0.35), "Body", 0.1, 20)
	return n


static func _wood_stick_model() -> Node3D:
	var n := Node3D.new()
	var mi := MeshKit.cylinder(n, 0.015, 0.34, Vector3.ZERO, MeshKit.mat("stick_zoom", Color(0.58, 0.46, 0.33), 0.9), "Stick", 0.011, 8)
	mi.rotation.z = deg_to_rad(35.0)
	return n


# ---------------------------------------------------------------- 持ち物

## 持ち物に加える（同じ物は重複しない）。加えた物を選択する。
func _give_coin10() -> void:
	_item_models["ten_yen"] = TowelRef.coin_model()
	add_item("ten_yen")


func add_item(id: String) -> bool:
	if inventory.has(id):
		return false
	SfxScript.play("pop")
	inventory.append(id)
	items_found[id] = true
	select_item(selected)   # 拾っただけでは手に持たない（1〜3 かホイールで選ぶ）
	if not _item_tutorial_shown:
		_item_tutorial_shown = true
		hud.show_message("持ち物は 1〜3 かマウスホイールで手に持つ。狙った先に F で使う。Q で拡大して調べられる。", 6.0)
	progress.save()
	return true


func remove_item(id: String) -> void:
	var i := inventory.find(id)
	if i < 0:
		return
	inventory.remove_at(i)
	if _item_models.has(id):
		(_item_models[id] as Node).free()
		_item_models.erase(id)
	select_item(mini(selected, inventory.size() - 1))


func select_item(i: int) -> void:
	if i < 0:
		selected = -1   # 何も持っていない
	elif i >= inventory.size():
		selected = -1 if inventory.is_empty() else clampi(i, 0, inventory.size() - 1)
	else:
		selected = i
	var names := []
	for id in inventory:
		names.append(item_name(id))
	hud.set_inventory(names, selected)
	if hud.is_zoom_open():
		_show_zoom()
	_refresh_torch_light()
	_refresh_headphones()


## UFOコインを n 枚ふやす（持ち物には1つの欄に「×枚数」でまとめる）。
func add_coin(n := 1) -> void:
	coin_count += n
	coins_total += n
	if not inventory.has("ufo_coin"):
		_item_models["ufo_coin"] = FishingScript.coin_model()
		add_item("ufo_coin")
	else:
		select_item(inventory.find("ufo_coin"))


## クレーンゲームで1枚使う。なければ false。
func txn_begin() -> void:
	txn += 1


func txn_end() -> void:
	txn = maxi(0, txn - 1)
	if txn == 0 and progress.save_deferred:
		progress.save_deferred = false
		progress.save()


func spend_coin() -> bool:
	if coin_count <= 0:
		return false
	if not _ufo_txn:
		_ufo_txn = true
		txn_begin()
	coin_count -= 1
	if coin_count == 0:
		remove_item("ufo_coin")
	else:
		select_item(inventory.find("ufo_coin"))
	return true


func item_name(id: String) -> String:
	if id == "ufo_coin":
		return "UFOコイン×%d" % coin_count
	if id == "bath_powder" and powder_used:
		return "ユブロマン（空）"
	return ITEMS[id]["name"]


func selected_item() -> String:
	return inventory[selected] if selected >= 0 and selected < inventory.size() else ""


## Q：選んだ持ち物を拡大して見る／閉じる。
func toggle_zoom() -> void:
	if hud.is_zoom_open() or selected_item().is_empty():
		hud.show_item_zoom(null, "", "")
	else:
		_show_zoom()


func _show_zoom() -> void:
	var id := selected_item()
	if id.is_empty():
		hud.show_item_zoom(null, "", "")
		return
	var desc: String = "空の容器。ゆずの香りだけ残っている。" if id == "bath_powder" and powder_used else ITEMS[id]["desc"]
	var model = _item_models.get(id)
	if id.begins_with("blank_card_"):
		# 暗い部屋で、トイレの青い光の下だけ、点の数が光って見える
		if not room.power_on and room.bath_light_on and room.bath_purple:
			var k := int(id.substr(11))
			model = Stage5Items.blank_card_model(CARD_DOTS[k], true)
			desc = "青い光の下で、点が光って見える。点の数：%d。" % CARD_DOTS[k]
	hud.show_item_zoom(model, item_name(id), desc)


## F の案内（照準の対象に選んだ物が使えるときだけ）。
func _use_prompt(target: Object) -> String:
	var id := selected_item()
	if id == "cork_gun" and player.pose != PlayerScript.Pose.TRANSITION:
		return "F：コルク銃を撃つ"
	if id == "mahjong" and player.pose == PlayerScript.Pose.KOTATSU_IN:
		return "F：一人麻雀を打つ"
	if id.is_empty() or target == null or player.pose == PlayerScript.Pose.TRANSITION:
		return ""
	# 何に効くかは教えない（持っているだけ・狙うだけで答えが出ないように）。手に持った物を、狙った先に使う、とだけ出す
	if String(target.get_meta("interact_id", "")).is_empty():
		return ""
	return "F：%sを使う" % item_name(id)


## F：選んだ持ち物を照準の対象に使う。失敗しても物は減らない。
func use_selected() -> void:
	if paused or cleared or player.pose == PlayerScript.Pose.TRANSITION:
		return
	var id := selected_item()
	if id.is_empty():
		return
	var target := player.get_focused(true)
	var tid := String(target.get_meta("interact_id", "")) if target else ""
	if id == "cork_gun":
		_fire(target)
		return
	if id == "mahjong":
		_start_mahjong()
		return
	if (id == "wood_stick" or id == "match_stick") and inventory.has("wood_stick") and inventory.has("match_stick"):
		_make_torch()
		return
	if id == "room_key" and tid == "window":
		if room.apartment.window_locked:
			room.apartment.window_locked = false
			SfxScript.play("click")
			hud.show_message(STAGE3["window_unlocked"])
			progress.discover("window_unlocked")
		else:
			hud.show_message(MESSAGES["cannot_use"])
		return
	if id == "wood_ladder" and (tid == "fuse_hatch" or tid == "ladder_placed" or tid == "liquor_cellar" or tid.begins_with("liquor_")):
		if not room.risen or room.ladder_placed:
			hud.show_message(MESSAGES["cannot_use"])
			return
		room.place_ladder()
		remove_item("wood_ladder")
		SfxScript.play("clunk")
		hud.show_message(STAGE4["ladder_placed"], 5.0)
		progress.discover("ladder_placed")
		return
	if id.begins_with("blank_card_"):
		_place_card(id, tid)
		return
	if (id == "crystal" and inventory.has("tp_core")) or (id == "tp_core" and inventory.has("crystal")):
		remove_item("crystal")
		remove_item("tp_core")
		_give_stage5("telescope")
		hud.show_message(STAGE5["telescope_make"], 5.0)
		SfxScript.play("chime", 1.2)
		return
	if id in ["blowgun_part", "tp_core2", "lint"] and inventory.has("blowgun_part") and inventory.has("tp_core2") and inventory.has("lint"):
		for part in ["blowgun_part", "tp_core2", "lint"]:
			remove_item(part)
		_give_stage5("blowgun")
		has_lint = false
		hud.show_message(STAGE5["blowgun_make"], 5.0)
		SfxScript.play("chime", 1.2)
		return
	if id == "blowgun":
		_shoot_blowgun()
		return
	if id == "magnifier":
		if tid == "feed_box":
			hud.show_message(STAGE5["magnifier_feed"], 7.0)
		elif tid == "closet_safe":
			hud.show_message(STAGE5["magnifier_safe"], 6.0)
		elif tid == "ceiling_dot":
			hud.show_message(STAGE5["magnifier_dot"], 6.0)
		else:
			hud.show_message(STAGE5["magnifier_use"])
		return
	if id == "telescope":
		if tid == "ceiling_dot":
			hud.show_message(STAGE5["ceiling_look"], 6.0)
			progress.discover("telescope_look")
			await get_tree().create_timer(3.0).timeout
			_open_reader("天井の点", ["小さな文字が、びっしりと…………いや、一言だけ。", "『九蓮宝燈』", "こたつの中の、ひとり麻雀のことだろうか。"], null, Color(0.1, 0.1, 0.12))
		else:
			hud.show_message(STAGE5["telescope_far"])
		return
	if id == "medal":
		_use_medal(tid)
		return
	if id == "prize_list":
		_open_reader("景品一覧表", ["つかみ取り　景品一覧", "1　懐中電灯\n2　虫眼鏡\n3　磁石つきの釣り針\n4　耳栓", "5　ごはん\n6　家の鍵\n7　吹き矢の部品\n8　詰め麻雀", "※景品は、この順番で出ます。"], null, Color(0.9, 0.85, 0.7))
		return
	if id == "bad_book":
		_flush_book(tid)
		return
	if id == "bad_book_wet":
		_open_reader("悪口本", ["黒かった表紙は、水を吸って、すっかり色が抜けている。", "『悪いことは、水に流そう。』", "……最後のページに、小さく、そう書いてあった。"], null, Color(0.55, 0.55, 0.6))
		return
	if id == "home_key":
		if tid == "front_door" and room.front_door.locked:
			room.front_door.unlock()
			hud.show_message(STAGE5["front_door_unlock"], 4.0)
			progress.discover("front_door_unlock")
		else:
			hud.show_message(MESSAGES["cannot_use"])
		return
	if id == "earplugs":
		earplugs_on = not earplugs_on
		AudioSettingsScript.set_earplugs(earplugs_on)
		SfxScript.play("rustle")
		hud.show_message(STAGE5["earplugs_on"] if earplugs_on else STAGE5["earplugs_off"])
		return
	if id == "rice_pack":
		var k = room.apartment.kitchen
		if k.eggs_held <= 0:
			hud.show_message(STAGE4["need_egg"])
			return
		k.eggs_held -= 1
		remove_item("rice_pack")
		SfxScript.play("plop")
		_give_stage4("cold_tkg")
		select_item(inventory.find("cold_tkg"))
		hud.show_message(STAGE4["cold_tkg_made"], 5.0)
		return
	if id == "cold_tkg" and tid == "microwave":
		_heat_tkg()
		return
	if id == "tkg":
		remove_item("tkg")
		SfxScript.play("pop")
		hud.show_message(STAGE4["tkg_eat"], 6.0)
		progress.discover("tkg_eaten")
		return
	if id == "hand_mirror" and tid == "gem":
		_use_mirror_on_gem()
		return
	if (id == "pickaxe" or id == "small_pickaxe") and tid.begins_with("balcony_wall_"):
		_hit_partition(id, tid.right(1))
		return
	if id == "pickaxe" and tid == "kotatsu_wall":
		room.apartment.kotatsu.break_wall()
		SfxScript.play("crack")
		SfxScript.play("thunk", 0.7)
		hud.show_message(STAGE4["wall_break"], 5.0)
		progress.discover("kotatsu_wall")
		return
	if BOOKMARK_KIND.has(id) and tid == "heirloom":
		_insert_bookmark(id)
		return
	if id == "door_knob" and tid == "fuse_hatch":
		if room.hatch_open:
			hud.show_message(MESSAGES["cannot_use"])
			return
		room.open_hatch()
		remove_item("door_knob")
		hud.show_message(STAGE3["hatch_open"])
		progress.discover("hatch_open")
		return
	if id == "driver" and tid == "breaker":
		if room.exterior.breaker.open_cover():
			hud.show_message(STAGE3["breaker_cover_open"])
			progress.discover("breaker_open")
		else:
			hud.show_message(MESSAGES["cannot_use"])
		return
	if id == "fuse" and tid == "breaker":
		match room.exterior.breaker.insert_fuse():
			"ok":
				remove_item("fuse")
			"closed":
				hud.show_message(STAGE3["breaker_cover_first"])
			_:
				hud.show_message(MESSAGES["cannot_use"])
		return
	if id == "soap" and tid in SINK_TARGETS:
		if room.sink.place_soap() == "ok":
			remove_item("soap")
			SfxScript.play("plop")
			hud.show_message(MESSAGES["soap_placed"])
			progress.discover("soap_placed")
		else:
			hud.show_message(MESSAGES["soap_dry"])
		return
	if id == "ten_yen" and tid in SINK_TARGETS:
		if room.sink.plug_in:
			hud.show_message(MESSAGES["cannot_use"])
			return
		room.sink.set_plug(true)
		remove_item("ten_yen")
		SfxScript.play("click")
		hud.show_message(MESSAGES["coin_on_sink"])
		progress.discover("sink_lid")
		return
	if id == "ten_yen" and tid in TUB_TARGETS:
		if room.bathtub.put_lid(false) == "already":
			hud.show_message(MESSAGES["cannot_use"])
			return
		remove_item("ten_yen")
		SfxScript.play("click")
		hud.show_message(MESSAGES["coin_on_tub"])
		return
	if id == "sinker" and tid in TUB_TARGETS:
		if room.bathtub.lid == "none":
			hud.show_message(MESSAGES["sinker_alone"])
			return
		if room.bathtub.put_lid(true) == "full":
			remove_item("sinker")
			SfxScript.play("clunk")
			hud.show_message(MESSAGES["lid_with_sinker"])
			progress.discover("tub_lid")
		else:
			hud.show_message(MESSAGES["cannot_use"])
		return
	if id == "paper" and tid in MIRROR_TARGETS:
		var shown := RoomScript.paper_model(false)
		hud.show_item_zoom(shown, "鏡に映ったメモ", "鏡に映った文字は、英語だった。『FLUSH』。")
		shown.free()   # hud は複製を使う
		hud.show_message(MESSAGES["paper_mirror"])
		progress.add_note("paper_flush", "鏡に映った英語", "『FLUSH』。水槽の餌箱のパスワードかもしれない。", "パスワード")
		progress.discover("mirror_paper")
		return
	if id == "driver" and tid in ["mirror_door", "mirror_lock"] and (room.mirror_cabinet.locked or room.mirror_cabinet.unlocking):
		if room.mirror_cabinet.unlock():
			hud.show_message(MESSAGES["cabinet_unlocked"])
		return
	if id == "driver" and tid == "door" and not door_open:
		door_open = true
		room.open_door()
		hud.show_message(MESSAGES["door_fixed"])
		return
	if id == "spare_roll" and tid in ["paper_holder", "paper_cover"]:
		match room.supplies.install_roll():
			"ok":
				remove_item("spare_roll")
				hud.show_message(MESSAGES["paper_installed"])
			"cover_closed":
				hud.show_message(MESSAGES["cover_closed"])
			"full":
				hud.show_message(MESSAGES["holder_full"])
		return
	if id == "bath_powder" and tid in TUB_TARGETS:
		if powder_used:
			hud.show_message(MESSAGES["powder_empty"])
			return
		match room.bathtub.add_powder(player.camera.global_position + player.camera.global_basis * Vector3(0, -0.2, -0.4)):
			"ok":
				powder_used = true
				select_item(selected)   # 所持品欄の名前を「（空）」へ
				hud.show_message(MESSAGES["powder_added"])
			"low":
				hud.show_message(MESSAGES["powder_need_water"])
		return
	hud.show_message(MESSAGES["cannot_use"])


func _exit_tree() -> void:
	# 拡大表示用の複製モデルはツリーの外にあるので、自分で解放する
	for m in _item_models.values():
		if is_instance_valid(m):
			(m as Node).free()
	_item_models.clear()


func _model_without_areas(node: Node3D) -> Node3D:
	var m := node.duplicate() as Node3D
	for a in m.find_children("*", "Area3D", true, false):
		a.free()
	m.visible = true
	return m


# ---------------------------------------------------------------- 脱出

func _physics_process(_delta: float) -> void:
	if paused or cleared:
		return
	if player.pose == PlayerScript.Pose.KOTATSU_IN:
		# こたつの中を這っていて、布団の外へ出たら、抜けて立つ
		var d := player.global_position - KotatsuScript.CENTER
		if absf(d.x) > KotatsuScript.OUT_DISTANCE or absf(d.z) > KotatsuScript.OUT_DISTANCE:
			if _crawl_out(d):
				SfxScript.play("rustle")
				hud.show_message(MESSAGES["kotatsu_exit"])
	region = _region_of(player.global_position)
	_update_space()
	if region.is_empty() or region == _last_region:
		return
	# 玄関ドアから廊下へ出た瞬間に、通ってきた経路で判定する（自室・ホールに入っただけではクリアしない）
	if region == "corridor" and _last_region == "hall":
		if inventory.has("yen100"):
			hud.show_message(ENDING["yen_hint"], 6.0)   # 百円玉を持って出ると、まだクリアにならない（エレベーターで 1 階へ）
		else:
			_clear("legit" if route_duct else "shortcut")
	elif region == "room" and room.risen and not room.power_on:
		progress.set_chapter(2)   # 第3幕　暗い部屋
		if not _dark_hinted:
			_dark_hinted = true
			hud.show_message(STAGE3["dark_hint"], 6.0, "voice")
	elif region == "lobby" and _last_region != "lobby" and not vending_done:
		hud.show_message(ENDING["lobby"], 5.0)
	elif region == "alley" and _last_region == "lobby" and not vending_done:
		hud.show_message(ENDING["vending_look"], 6.0)
	elif region in StoryData.REGION_MUTTERS and not muttered.has(region) and _last_region != "":
		muttered[region] = true
		_mutter(StoryData.REGION_MUTTERS[region])
	_last_region = region


## 場所ごとの音の響き。浴室は大きく響き、廊下も響く。こたつの中ではこもる。
## こたつの中から布団の外へ出る。本体の判定を戻すと、這っている体（半径 0.2）が本体（半幅 0.425）に食い込んで動けなくなるので、
## 先に判定を戻して、布団の縁から体が離れる位置（出た向きに 0.7m、ずらした位置も）へ移してから立つ。どこも空いていなければ出ない（そのまま這える）。
func _crawl_out(d: Vector3) -> bool:
	var k = room.apartment.kotatsu
	k.set_solid(true)
	var axis_x := absf(d.x) >= absf(d.z)
	var sgn := signf(d.x) if axis_x else signf(d.z)
	var here := player.global_position
	for dist in [0.7, 0.76, 0.84]:
		for lat in [0.0, 0.12, -0.12, 0.25, -0.25]:
			var c := KotatsuScript.CENTER
			c.y = here.y
			if axis_x:
				c += Vector3(sgn * dist, 0.0, d.z + lat)
			else:
				c += Vector3(d.x + lat, 0.0, sgn * dist)
			if player.is_space_free(c, PlayerScript.CROUCH_BODY_HEIGHT, PlayerScript.BODY_RADIUS):
				player.global_position = c
				player.leave_crawl()
				return true
	k.set_solid(false)
	return false


const SPACES := {"bath": [0.32, 20000.0], "hall": [0.14, 20000.0], "room": [0.07, 20000.0], "corridor": [0.3, 20000.0],
		"duct": [0.28, 5000.0], "balcony": [0.02, 20000.0], "car": [0.3, 12000.0], "washitsu": [0.12, 9000.0], "lobby": [0.28, 20000.0], "alley": [0.03, 20000.0]}
var _space_key := ""


func _update_space() -> void:
	var key := region
	if player.pose == PlayerScript.Pose.KOTATSU_IN:
		key = "kotatsu"
	elif player.pose == PlayerScript.Pose.CLOSET:
		key = "closet"
	if key == _space_key or key.is_empty():
		return
	_space_key = key
	var sp: Array = SPACES.get(key, [0.07, 20000.0]) if key != "kotatsu" and key != "closet" else [0.03, 900.0]
	AudioSettingsScript.set_space(sp[0], sp[1])


## 足元の素材（足音用）。
func _surface_at(p: Vector3) -> String:
	match _region_of(p) if not _region_of(p).is_empty() else region:
		"bath":
			return "tile"
		"corridor", "alley":
			return "concrete"
		"lobby":
			return "tile"
		"duct", "balcony", "car":
			return "metal"
		"washitsu":
			return "wood"
		"room":
			var rug: Vector3 = SmallPropsScript.RUG_CENTER
			var hs: Vector2 = SmallPropsScript.RUG_SIZE * 0.5
			if absf(p.x - rug.x) < hs.x and absf(p.z - rug.z) < hs.y:
				return "rug"
			var c = room.apartment.cellar
			if c.is_closed() and p.x > c.HOLE_X.x and p.x < c.HOLE_X.y and p.z > c.HOLE_Z.x and p.z < c.HOLE_Z.y:
				return "hollow"
	return "wood"


## 足元の位置の区画。敷居など境目の上では空（直前の区画を保つ）。
func _region_of(p: Vector3) -> String:
	if p.y < -70.0:
		return "washitsu" if p.x > 20.0 else "car"
	if p.y < -10.0:
		# 1 階：廊下の真下の玄関ホール／路地（入口から自動販売機まで）
		if p.x > -2.75 and p.x < -0.95 and p.z > -1.3:
			return "lobby"
		return "alley"
	if CorridorScript.in_corridor(p):
		return "corridor"
	if player.pose == PlayerScript.Pose.DUCT or ExteriorScript.in_duct(p):
		return "duct"
	if ApartmentScript.in_room(p):
		return "room"
	if ApartmentScript.in_hall(p):
		return "hall"
	var b: AABB = ExteriorScript.BALCONY
	if p.x > b.position.x and p.x < b.end.x and p.z > b.position.z and p.z < -1.25 and p.y > -0.2 and p.y < 2.0:
		return "balcony"
	if absf(p.x) < 0.9 and absf(p.z) < 1.2 and p.y < 2.0:
		return "bath"
	return ""


func _clear(route: String) -> void:
	cleared = true
	clear_route = route
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var title: String = CLEAR_TITLES[route]
	var stats := _clear_stats_text()
	var rank := ProgressScript.rank_for(play_time, progress.hints_used)
	if credits_enabled:
		# エンドロールを流しながら、最後にクリア画面
		hud.show_credits(CreditsData.lines(route), func() -> void: hud.show_clear(title, stats, rank))
	else:
		hud.show_clear(title, stats, rank)


## エレベーターに乗る（廊下の南の端）：暗転 → 箱の中で 5 から 1 へ → 扉が開く → 暗転 → 1 階の玄関ホール。
func _ride_elevator() -> void:
	if riding or cleared:
		return
	riding = true
	player.controls_enabled = false
	SfxScript.play("click")
	hud.show_message(ENDING["elevator_ride"], 3.0)
	var car = room.get_node("ElevatorCar")
	await hud.fade_to(1.0, 0.8 / ride_speed).finished
	car.close_doors_now()
	car.set_floor(5)
	player.global_position = room.PREVIEW_CAR_POS + Vector3(0.0, 0.05, -0.3)
	player.rotation.y = PI
	player._pitch = 0.0
	player.camera.rotation.x = 0.0
	await hud.fade_to(0.0, 0.8 / ride_speed).finished
	await get_tree().create_timer(0.9 / ride_speed).timeout
	for f in RIDE_STOPS:
		SfxScript.play("rumble")
		await get_tree().create_timer(1.1 / ride_speed).timeout
		car.set_floor(f)
	SfxScript.play("pop")
	await get_tree().create_timer(0.6 / ride_speed).timeout
	var tw: Tween = car.open_doors(1.2 / ride_speed)
	hud.show_message(ENDING["elevator_arrive"], 3.0)
	await tw.finished
	await get_tree().create_timer(1.0 / ride_speed).timeout
	await hud.fade_to(1.0, 0.7 / ride_speed).finished
	player.global_position = Vector3(room.ENTRANCE_POS.x, room.ENTRANCE_POS.y + 0.05, 5.2)   # ホールの突き当たりのエレベーターの前
	player.rotation.y = 0.0   # -z（アーチの向き）を向く
	player._pitch = 0.0
	player.camera.rotation.x = 0.0
	await hud.fade_to(0.0, 0.9 / ride_speed).finished
	player.controls_enabled = true
	riding = false


## 自動販売機（ベランダの真下）：身長が足りないと最上段のボタンに届かない。百円玉で炭酸リンゴジュースを買って飲むと、真のクリア。
func _use_vending() -> void:
	if vending_done or cleared:
		return
	if player.eye_height < VENDING_REACH:
		hud.show_message(ENDING["vending_far"], 5.0)
		return
	if not inventory.has("yen100"):
		hud.show_message(ENDING["vending_no_money"])
		return
	if vending_busy:
		return
	vending_busy = true   # 演出の途中で保存されても、百円玉はまだ手元にある（最初からやり直せる）
	txn_begin()
	player.controls_enabled = false
	progress.discover("vending")
	SfxScript.play("click")
	hud.show_message(ENDING["vending_coin"], 4.0)
	await get_tree().create_timer(3.2 / ride_speed).timeout
	SfxScript.play("pop")
	hud.show_message(ENDING["vending_drop"], 3.0)
	await get_tree().create_timer(2.6 / ride_speed).timeout
	hud.show_message(ENDING["vending_drink"], 3.5)
	await get_tree().create_timer(3.0 / ride_speed).timeout
	hud.show_message(ENDING["vending_last"], 4.5)
	await get_tree().create_timer(3.8 / ride_speed).timeout
	hud.voice_silenced = false   # 神の声は黙っていても、エンディングの一言だけは出る
	hud.show_message(ENDING["vending_voice"], 4.5, "voice")
	await get_tree().create_timer(4.0 / ride_speed).timeout
	vending_done = true
	vending_busy = false
	remove_item("yen100")
	txn_end()
	_clear("true")


## 百円玉を持ち物に加える（開発用：環境変数 TOIRE_YEN100=1 で最初から持つ。入手方法は、これから作る段階 6）。
func give_yen100() -> void:
	_item_models["yen100"] = TowelRef.coin_model()
	add_item("yen100")


## つかみ取りの景品（固定順）が取り出し口に落ちた：持ち物に入る。
func _on_prize_won(index: int) -> void:
	if index < 0 or index >= PRIZES.size():
		return
	var id: String = PRIZES[index]
	_prize_pending = true
	await get_tree().create_timer(1.0).timeout
	_prize_pending = false
	if id == "rice_pack" and (inventory.has(id) or items_found.has(id)):
		return
	_give_stage5(id)
	hud.show_message(STAGE5["prize_" + id], 6.0)


func _give_stage5(id: String) -> void:
	_give_stage4_model(id)
	add_item(id)
	progress.discover(id)
	if id == "magnet_hook":
		fishing.magnet = true


## 星の印のフィギュアを撃ち落とした：コインが 1 枚、落ちた先に出る。
func _on_star_down(pos: Vector3) -> void:
	hud.show_message(STAGE5["star_hit"], 5.0)
	progress.discover("star_figure")
	if shot_coin_taken or shot_coin_node != null:
		return
	spawn_shot_coin(pos)


func spawn_shot_coin(pos: Vector3) -> void:
	shot_coin_node = Node3D.new()
	shot_coin_node.name = "ShotCoin"
	shot_coin_node.position = pos + Vector3(0, 0.012, 0)
	room.apartment.add_child(shot_coin_node)
	var cm := FishingScript.coin_model()
	cm.rotation.x = deg_to_rad(90.0)
	cm.scale = Vector3(0.6, 0.6, 0.6)
	shot_coin_node.add_child(cm)
	var a := MeshKit.interact_area(shot_coin_node, "ShotCoinArea", "shot_coin")
	MeshKit.shape_box(a, Vector3(0.16, 0.08, 0.16), Vector3.ZERO)


# ---------------------------------------------------------------- 段階 4：手かがみ・宝石・ツルハシ・こたつの壁・隣の和室

func _give_stage4_model(id: String) -> void:
	match id:
		"hand_mirror":
			_item_models[id] = Stage4Items.hand_mirror_model()
		"pickaxe":
			_item_models[id] = Stage4Items.pickaxe_model()
		"crystal":
			_item_models[id] = Stage4Items.crystal_model()
		"bm_dog", "bm_monkey", "bm_pheasant":
			_item_models[id] = Stage4Items.bookmark_model(BOOKMARK_KIND[id])
		"lighter":
			_item_models[id] = Stage4Items.lighter_model()
		"flashlight":
			_item_models[id] = Stage5Items.flashlight_model()
		"magnifier":
			_item_models[id] = Stage5Items.magnifier_model()
		"magnet_hook":
			_item_models[id] = Stage5Items.magnet_hook_model()
		"earplugs":
			_item_models[id] = Stage5Items.earplugs_model()
		"home_key":
			_item_models[id] = Stage5Items.home_key_model()
		"blowgun_part":
			_item_models[id] = Stage5Items.blowgun_part_model()
		"mahjong_tiles":
			_item_models[id] = Stage5Items.mahjong_tiles_model()
		"blowgun":
			_item_models[id] = Stage5Items.blowgun_model()
		"small_pickaxe":
			_item_models[id] = Stage5Items.small_pickaxe_model()
		"headphones":
			_item_models[id] = Stage5Items.headphones_model()
		"tp_core", "tp_core2":
			_item_models[id] = Stage5Items.tp_core_model()
		"telescope":
			_item_models[id] = Stage5Items.telescope_model()
		"medal":
			_item_models[id] = Stage5Items.medal_model()
		"blank_card_0", "blank_card_1", "blank_card_2", "blank_card_3":
			_item_models[id] = Stage5Items.blank_card_model(0, false)
		"prize_list":
			_item_models[id] = Stage5Items.prize_list_model()
		"bad_book":
			_item_models[id] = Stage5Items.bad_book_model(false)
		"bad_book_wet":
			_item_models[id] = Stage5Items.bad_book_model(true)
		"rice_pack":
			_item_models[id] = Stage4Items.rice_model()
		"cold_tkg":
			_item_models[id] = Stage4Items.tkg_model(false)
		"tkg":
			_item_models[id] = Stage4Items.tkg_model(true)
		"wood_ladder":
			_item_models[id] = Stage4Items.ladder_model()
		"photo_tkg":
			_item_models[id] = Stage4Items.photo_model()


func _give_stage4(id: String) -> void:
	_give_stage4_model(id)
	add_item(id)
	progress.discover(id)


## 手かがみで、トイレの青い光を宝石へはね返す。部屋が暗く（停電）、トイレの電球が青くついているときだけ。近づいて、向きを合わせる（簡易判定）。
func _use_mirror_on_gem() -> void:
	var apt = room.apartment
	if apt.gem_broken:
		hud.show_message(MESSAGES["cannot_use"])
		return
	if room.power_on:
		hud.show_message(STAGE4["gem_bright"])
		return
	if not room.bath_light_on:
		hud.show_message(STAGE4["gem_no_light"])
		return
	if not room.bath_purple:
		hud.show_message(STAGE4["gem_white"])
		return
	if player.global_position.distance_to(apt.gem_root.global_position) > GEM_REACH:
		hud.show_message(STAGE4["gem_far"])
		return
	var from_p: Vector3 = player.camera.global_position + player.camera.global_basis * Vector3(0.15, -0.15, -0.3)
	var bath_p: Vector3 = room.bath_light.global_position
	_flash_beam(bath_p, from_p)
	_flash_beam(from_p, apt.gem_root.global_position + Vector3(0, 0.1, 0))
	apt.break_gem()
	SfxScript.play("chime", 1.2)
	hud.show_message(STAGE4["gem_break"], 6.0)
	progress.discover("gem")
	await get_tree().create_timer(2.8).timeout
	hud.show_message(STAGE4["gem_after"], 5.0)


## 白紙のトランプを金庫に置く：点の多い順（8→6→4→2）。順番が違えば、置いた分もはね返る。
func _place_card(id: String, tid: String) -> void:
	var c = room.apartment.closet
	if tid != "closet_safe" or c.safe_open:
		hud.show_message(MESSAGES["cannot_use"])
		return
	var k := int(id.substr(11))
	var dots: int = CARD_DOTS[k]
	if c.place_card(dots):
		remove_item(id)
		cards_in_safe.append(k)
		SfxScript.play("chime", 0.7)
		hud.show_message(STAGE5["safe_place"] if not c.safe_open else STAGE5["safe_open"], 4.0)
		if c.safe_open:
			progress.discover("safe_open")
			await get_tree().create_timer(1.2 / ride_speed).timeout
			if not inventory.has("prize_list"):
				_give_stage5("prize_list")
				safe_list_taken = true
	else:
		# 置いた分もはね返る：置いてあったカードは、持ち物に戻る
		for kk in 4:
			var cid := "blank_card_%d" % kk
			if kk in cards_in_safe and not inventory.has(cid):
				_give_stage5(cid)
		cards_in_safe.clear()
		hud.show_message(STAGE5["safe_wrong"], 4.0)


# ---------------------------------------------------------------- 物語（オープニング・独り言・メモ・日記）

func hiding_in_closet() -> bool:
	return player.pose == PlayerScript.Pose.CLOSET


## 独り言：脱出には関係しない、胸のざわつく一言。
func _mutter(text: String) -> void:
	if paused or cleared or reading:
		return
	hud.show_message(text, 5.5)


## 新しくはじめたとき：目覚め → インターホン → ドアが開かない → 閉じこもった覚えがない。
func _opening_event() -> void:
	await get_tree().create_timer(5.5).timeout
	if not is_inside_tree() or cleared:
		return
	room.apartment.intercom.ring()
	await get_tree().create_timer(6.0).timeout
	if not is_inside_tree() or cleared:
		return
	hud.show_message("出ようとして、ドアに手をかけた。……閉まっている。外から、誰かが、閉めたのか。", 6.0)
	await get_tree().create_timer(7.5).timeout
	if not is_inside_tree() or cleared:
		return
	hud.show_message("どうして、自分は、トイレに閉じこもっている？　思い出せない。……ここが、自分の部屋であることだけは、たしかなのに。", 7.0)


## 動作のない飾りを調べると、貼り紙に気づく（文字が欠けていて、ちゃんとは読めない）。
func _maybe_find_memo(id: String) -> void:
	if not StoryData.MEMOS.has(id) or memos_found.has(id):
		return
	memos_found.append(id)
	var memo: Array = StoryData.MEMOS[id]
	progress.add_note("memo_" + memo[0], "メモ " + memo[0], memo[1], "メモ")
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree() or reading or paused or cleared:
		return
	hud.show_message("……何か、貼ってある。メモだ。", 3.0)
	await get_tree().create_timer(1.0).timeout
	if reading or paused or cleared:
		return
	_open_reader("メモ " + memo[0], [memo[1]], null, Color(0.9, 0.88, 0.72))
	var n := memos_found.size()
	_reader_after = func() -> void:
		if n == 3:
			_mutter("（また、メモだ。……誰が、こんなものを）")
		elif n == 6:
			_mutter("（全部、同じ人の字だ。……見覚えが、ある気がする）")
		elif n == 10:
			_mutter("（十枚目。……「ごめんね」って、誰に言っているんだ）")


func _read_diary(pages: Array, id: String, title: String, note_text: String) -> void:
	progress.add_note(id, title, note_text, "日記")
	_open_reader(title, pages, null, Color(0.78, 0.7, 0.55))
	if id == "diary_grandma":
		_reader_after = func() -> void:
			_mutter("（……あのインターホンは、おばあちゃんだったのか）")
	else:
		_reader_after = func() -> void:
			_mutter("（コタニ……？　書いた覚えが、ない。誰なんだ、この人は）")


## 吹き矢を撃つ：ベランダで、向かいの壁の的へ。目の高さが 160 cm 未満だと、的が庇に隠れて見えない。
func _shoot_blowgun() -> void:
	if not ExteriorScript.in_balcony(player.global_position):
		hud.show_message(STAGE5["blowgun_need_balcony"])
		return
	if darts_used >= DARTS_MAX:
		hud.show_message(STAGE5["blowgun_out"])
		return
	var ext = room.exterior
	var sign_ok: bool = player.eye_height >= ExteriorScript.SIGN_MIN_EYE
	ext.set_blowgun_sign_visible(sign_ok)
	if not sign_ok and not ext.sign_hit:
		hud.show_message(STAGE5["blowgun_hidden"], 6.0)
	SfxScript.play("pop", 1.4)
	var dir: Vector3 = -player.camera.global_basis.z
	var r: String = ext.shoot_dart(player.camera.global_position, dir)
	darts_used += 1
	match r:
		"hit":
			hud.show_message(STAGE5["blowgun_hit"], 5.0)
			progress.discover("blowgun_hit")
			await get_tree().create_timer(1.6 / ride_speed).timeout
			ext.drop_dart_coin()
			SfxScript.play("chime", 0.8)
		"miss":
			if sign_ok or ext.sign_hit:
				hud.show_message(STAGE5["blowgun_miss"] % (DARTS_MAX - darts_used), 3.0)
		_:
			hud.show_message(STAGE5["blowgun_none"], 3.0)


# ---------------------------------------------------------------- ヘッドホン・物を置く

## 手に持った物がヘッドホンなら、つけて音が流れる（はじめは話し声、そのあと BGM がくり返す）。持ち物から外すと止まる。
func _refresh_headphones() -> void:
	var on := selected_item() == "headphones" and not cleared
	if on == _hp_on:
		return
	_hp_on = on
	AudioSettingsScript.set_headphones(on)
	if on:
		if _hp_player == null:
			_hp_player = AudioStreamPlayer.new()
			_hp_player.name = "HeadphoneSound"
			_hp_player.bus = "Master"
			_hp_player.volume_db = -4.0
			add_child(_hp_player)
		if _hp_audio.ready():
			_start_headphones()
		else:
			hud.show_message(STAGE5["hp_loading"], 4.0)
			_hp_audio.generate_async()
	else:
		if _hp_player:
			_hp_player.stop()
		hud.show_message(STAGE5["hp_off"], 2.5)


func _start_headphones() -> void:
	_hp_player.stream = _hp_audio.stream
	_hp_player.play()
	hud.show_message(STAGE5["hp_on"], 5.0)
	progress.discover("headphones")
	var token := Time.get_ticks_msec()
	_hp_token = token
	await get_tree().create_timer(5.5).timeout
	if _hp_on and _hp_token == token:
		hud.show_message(STAGE5["hp_voice"], 6.0)
	await get_tree().create_timer(HeadphoneAudio.VOICE_SEC - 5.5).timeout
	if _hp_on and _hp_token == token:
		hud.show_message(STAGE5["hp_bgm"], 6.0)


var _hp_token := 0
const PLACE_REACH := 2.4


## G：手に持った物を、狙った先に置く。置いた物は、あとで拾える。
func _drop_selected() -> void:
	if paused or cleared or reading or gaming or mj_playing or peeping or txn > 0 or riding:
		return
	var id := selected_item()
	if id.is_empty():
		hud.show_message(STAGE5["drop_none"])
		return
	if id == "ufo_coin" or not (player.pose in [PlayerScript.Pose.WALK, PlayerScript.Pose.CROUCH, PlayerScript.Pose.SEATED, PlayerScript.Pose.KOTATSU_SEAT, PlayerScript.Pose.KOTATSU_IN]):
		hud.show_message(STAGE5["drop_no"])
		return
	var space := get_viewport().world_3d.direct_space_state
	var from: Vector3 = player.camera.global_position
	var dir: Vector3 = -player.camera.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * PLACE_REACH, MeshKit.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	var p: Vector3 = hit.position + hit.normal * 0.03 if not hit.is_empty() else from + dir * 1.0
	# その真下の面（床・机・棚の上）へ落とす
	var down := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.1, 0), p - Vector3(0, 3.0, 0), MeshKit.LAYER_WORLD)
	var floor_hit := space.intersect_ray(down)
	if floor_hit.is_empty():
		hud.show_message(STAGE5["drop_here"])
		return
	p = floor_hit.position
	_place_item(id, p, randf() * TAU)
	var nm := item_name(id)
	remove_item(id)
	SfxScript.play("thunk", 1.3, -6.0)
	hud.show_message(STAGE5["drop_ok"] % nm, 3.0)
	progress.save()


## 床や机に置かれた持ち物を作る（置いたときと、保存からの復元の両方）。
func _place_item(id: String, pos: Vector3, yaw: float, model: Node3D = null) -> void:
	var holder := Node3D.new()
	holder.name = "Placed_%s_%d" % [id, placed_items.size()]
	holder.set_meta("item_id", id)
	add_child(holder)
	holder.global_position = pos
	holder.rotation.y = yaw
	var src: Node3D = model if model != null else _item_models.get(id)
	var m: Node3D
	if src != null:
		m = src.duplicate()
	else:
		m = MeshKit.sphere(holder, 0.04, Vector3.ZERO, MeshKit.mat("placed_generic", Color(0.7, 0.7, 0.72), 0.7))
		m.get_parent().remove_child(m)
	holder.add_child(m)
	m.position = Vector3(0, 0.05, 0)
	var a := MeshKit.interact_area(holder, "PlacedArea", "placed_item", null)
	MeshKit.shape_box(a, Vector3(0.22, 0.16, 0.22), Vector3(0, 0.07, 0))
	placed_items.append({"id": id, "node": holder})


func _pickup_placed(target: Object) -> void:
	var holder: Node3D = (target as Node).get_parent() as Node3D
	if holder == null or not holder.has_meta("item_id"):
		return
	var id: String = holder.get_meta("item_id")
	if inventory.has(id):
		hud.show_message(MESSAGES["cannot_use"])
		return
	var model: Node3D = null
	for c in holder.get_children():
		if c is Node3D and not (c is Area3D):
			model = c
			break
	if model:
		_item_models[id] = model.duplicate()
	for i in placed_items.size():
		if placed_items[i].node == holder:
			placed_items.remove_at(i)
			break
	holder.queue_free()
	add_item(id)
	hud.show_message(STAGE5["placed_pick"] % item_name(id), 3.0)


## メダルを、つかみ取りに入れる：百円玉に変わる（電気が必要）。
func _use_medal(tid: String) -> void:
	if tid != "ufo_catcher" or not room.power_on:
		hud.show_message(MESSAGES["cannot_use"])
		return
	txn_begin()   # メダルは、百円玉に変わるまで手元に残る（途中で保存されない）
	hud.show_message(STAGE5["medal_use"], 3.0)
	SfxScript.play("click")
	await get_tree().create_timer(2.4 / ride_speed).timeout
	remove_item("medal")
	give_yen100()
	txn_end()
	SfxScript.play("chime")
	hud.show_message(STAGE5["medal_yen"], 6.0)
	progress.discover("yen100")


## ダクトの中で耳栓をつけると、うなりが消えて、壁の向こうの規則正しい音が聞こえる（こたつの奥のほうこう）。
func _update_duct_sound() -> void:
	if region != "duct" or not earplugs_on or _duct_heard:
		return
	_duct_heard = true
	hud.show_message(STAGE5["duct_sound"], 7.0)
	progress.discover("duct_sound")
	progress.add_note("duct_sound", "ダクトの音", "耳栓をすると、ダクトのうなりが消えて、トン、トン、トトン……と壁の向こうから規則正しい音が聞こえた。こたつの奥のほうこうだ。", "手がかり")


## 手かがみではね返した青い光の筋（from → to）を、少しのあいだ光らせて消す。
func _flash_beam(from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 0.05:
		return
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.012
	cyl.height = len
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.6, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.55, 1.0)
	mat.emission_energy_multiplier = 3.0
	m.material_override = mat
	add_child(m)
	m.global_position = (from + to) * 0.5
	var up := Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	m.look_at(to, up)
	m.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.4)
	tw.tween_callback(m.queue_free)


## 保存からの復元：ベランダの隔て板：大きなツルハシは 62 回、小さなツルハシは 1994 回で割れる。長押しでくり返し叩ける。
func _hit_partition(tool_id: String, side: String) -> void:
	var ext = room.exterior
	if ext.part_open[side]:
		return
	var need: int = ext.PART_HITS[tool_id]
	wall_hits[side] += 1
	var ratio := float(wall_hits[side]) / float(need)
	SfxScript.play("thunk", 0.7 + randf() * 0.2, -3.0)
	ext.set_partition_damage(side, ratio)
	if wall_hits[side] == 1:
		hud.show_message(STAGE5["wall_hit"], 1.5)
	elif wall_hits[side] == int(need * 0.25):
		hud.show_message(STAGE5["wall_q1"], 3.0)
	elif wall_hits[side] == int(need * 0.5):
		hud.show_message(STAGE5["wall_q2"], 3.0)
	elif wall_hits[side] == int(need * 0.8):
		hud.show_message(STAGE5["wall_q3"], 3.0)
	if wall_hits[side] >= need:
		ext.break_partition(side)
		hud.show_message(STAGE5["wall_%s_break" % side], 6.0)
		progress.discover("wall_" + side)
		progress.save()


## 長押しで、隔て板を叩きつづける。
func _update_wall_hold(delta: float) -> void:
	var sel := selected_item()
	if not (sel == "pickaxe" or sel == "small_pickaxe") or not Input.is_action_pressed("use_item") or paused or cleared or reading:
		_wall_hold = 0.0
		return
	var t := player.get_focused(true)
	var tid := String(t.get_meta("interact_id", "")) if t else ""
	if not tid.begins_with("balcony_wall_"):
		_wall_hold = 0.0
		return
	_wall_hold += delta
	if _wall_hold >= 0.4:
		_wall_hold -= 0.12 if sel == "pickaxe" else 0.025
		_hit_partition(sel, tid.right(1))


## おばあちゃんの道具箱：釣りで手に入る種類が、ぜんぶ並んでいる。底に小さなツルハシ。
func _open_chest() -> void:
	progress.discover("granny_chest")
	hud.show_message(STAGE5["chest_open"], 5.0)
	var by := {"ゴミ": [], "お宝": [], "アイテム": []}
	for c in FishingScript.CATCHES:
		by[c[0]].append(c[1])
	var pages := []
	for k in ["ゴミ", "お宝", "アイテム"]:
		var names: Array = by[k]
		for i in range(0, names.size(), 6):
			pages.append("%s（%d 種類のうち）\n\n%s" % [k, names.size(), "\n".join(names.slice(i, i + 6))])
	_open_reader("釣りの道具箱", pages, null, Color(0.45, 0.3, 0.18))
	if not chest_small_taken and not inventory.has("small_pickaxe") and not items_found.has("small_pickaxe"):
		chest_small_taken = true
		_reader_after = func() -> void:
			_give_stage5("small_pickaxe")
			hud.show_message(STAGE5["chest_small"], 5.0)


## お隣のベランダの奥まで行く：窓から部屋へ入って、脱出。
func _check_neighbor_escape() -> void:
	var ext = room.exterior
	var x: float = player.global_position.x
	if ext.part_open["w"] and not _neighbor_seen and x < 1.0:
		_neighbor_seen = true
		hud.show_message(STAGE5["neighbor_balcony"], 5.0)
	if ext.part_open["e"] and not _granny_seen and x > 4.0:
		_granny_seen = true
		hud.show_message(STAGE5["granny_balcony"], 5.0)
	if ext.part_open["w"] and x < -1.6 and player.global_position.y > -0.5 and not cleared:
		_clear("neighbor")


## 悪口本を、トイレ（浮き上がった浴室）の便器に流す：本が流れて、便器が詰まる。濡れた本が浮かび、コインが 1 枚こぼれる（5 枚目）。
func _flush_book(tid: String) -> void:
	if not (tid in ["toilet", "toilet_seat", "toilet_lid", "flush_lever", "toilet_slippers"]):
		hud.show_message(STAGE5["flush_not_here"])
		return
	var t = room.toilet
	if t.clogged or t.flushing:
		hud.show_message(MESSAGES["cannot_use"])
		return
	if not t.lid_open:
		hud.show_message(STAGE5["flush_need_lid"])
		return
	remove_item("bad_book")
	t.flush()
	hud.show_message(STAGE5["flush_book"], 4.0)
	progress.discover("bad_book_flush")
	await get_tree().create_timer(2.8 / ride_speed).timeout
	t.clog()
	hud.show_message(STAGE5["clog"], 5.0)
	await get_tree().create_timer(3.0 / ride_speed).timeout
	_give_stage5("bad_book_wet")
	add_coin(1)
	SfxScript.play("chime")
	hud.show_message(STAGE5["book_back"], 6.0)


## 冷めた TKG を電子レンジでチンする（電気が必要）。
func _heat_tkg() -> void:
	if not room.power_on:
		hud.show_message(POWER_DEAD["microwave"])
		return
	if _mw_busy:
		return
	_mw_busy = true
	remove_item("cold_tkg")
	hud.show_message(STAGE4["microwave_start"], 3.0)
	SfxScript.play("buzz", 0.6, -8.0)
	await get_tree().create_timer(3.2 / ride_speed).timeout
	for i in 3:
		SfxScript.play("beep", 1.1)
		await get_tree().create_timer(0.35 / ride_speed).timeout
	_give_stage4("tkg")
	select_item(inventory.find("tkg"))
	hud.show_message(STAGE4["microwave_done"], 5.0)
	_mw_busy = false


func _has_light() -> bool:
	return (_torch_light != null and _torch_light.visible) or (_flash_light != null and _flash_light.visible)


func _look_scroll() -> void:
	if not _has_light():
		hud.show_message(STAGE4["scroll_dark"])
		return
	if absf(player.eye_height - JapaneseRoomScript.SCROLL_EYE) <= JapaneseRoomScript.SCROLL_TOLERANCE:
		hud.show_message(STAGE4["scroll_aligned"], 6.0)
		progress.discover("scroll_aligned")
		progress.add_note("scroll_order", "掛け軸の影絵", "目の高さがぴったり 142 cm のとき、墨が影絵に揃う。上から、犬・猿・キジ。栞を差す順番だ。", "手がかり")
	else:
		hud.show_message(STAGE4["scroll_blotch"])


## 掛け軸は、目の高さがぴったり（142 cm ±2.5cm）で、明かりを持って見ているときだけ、影絵が揃って見える。
func _update_scroll(delta: float) -> void:
	if region != "washitsu" or room.washitsu == null:
		return
	var aligned := absf(player.eye_height - JapaneseRoomScript.SCROLL_EYE) <= JapaneseRoomScript.SCROLL_TOLERANCE and _has_light()
	_scroll_a = move_toward(_scroll_a, 1.0 if aligned else 0.0, delta * 3.0)
	room.washitsu.set_scroll_alignment(_scroll_a)


func _insert_bookmark(id: String) -> void:
	var w = room.washitsu
	if w.heirloom_open:
		hud.show_message(STAGE4["heirloom_done"])
		return
	if id != BOOKMARK_ORDER[w.slots_filled]:
		SfxScript.play("buzz", 1.0, -6.0)
		hud.show_message(STAGE4["slot_wrong"])
		return
	remove_item(id)
	w.light_slot(w.slots_filled)
	w.slots_filled += 1
	SfxScript.play("click")
	hud.show_message(STAGE4["slot_ok"] % w.slots_filled)
	if w.slots_filled >= 3:
		await get_tree().create_timer(1.2).timeout
		w.open_heirloom()
		SfxScript.play("chime")
		hud.show_message(STAGE4["heirloom_open"], 5.0)
		progress.discover("heirloom_open")


func _take_photo() -> void:
	var w = room.washitsu
	if inventory.has("photo_tkg") or w.photo_taken:
		return
	w.take_photo()
	_give_stage4("photo_tkg")
	progress.add_note("tkg_recipe", "写真の裏のレシピ", "ご飯と卵で『冷めたTKG』を作る。それを電子レンジでチンする。", "手がかり")
	hud.show_message(STAGE4["photo_pickup"], 6.0)
	await get_tree().create_timer(4.5).timeout
	god_silent = true
	hud.voice_silenced = true
	hud.show_message(STAGE4["god_silent"], 5.0)


## こたつの中の穴から、隣の和室へ。暗転して移る。環境光を落として、真っ暗にする（明かりがほしい）。
func _enter_washitsu() -> void:
	if washitsu_transit or player.pose != PlayerScript.Pose.KOTATSU_IN:
		return
	washitsu_transit = true
	player.controls_enabled = false
	SfxScript.play("rustle")
	await hud.fade_to(1.0, 0.6).finished
	_ambient_before = room.sky_clock.ambient_scale
	room.sky_clock.ambient_scale = 0.01
	room.sky_clock.set_time(room.sky_clock.time)
	room.apartment.kotatsu.set_solid(true)
	player.global_position = room.WASHITSU_POS + JapaneseRoomScript.SPAWN
	player.rotation.y = -PI * 0.5
	player._pitch = 0.0
	player.camera.rotation.x = 0.0
	player.leave_crawl()
	progress.set_chapter(3)   # 第4幕　隣の和室
	progress.discover("washitsu")
	await hud.fade_to(0.0, 0.8).finished
	player.controls_enabled = true
	washitsu_transit = false
	hud.show_message(STAGE4["washitsu_in"], 5.0)


func _leave_washitsu() -> void:
	if washitsu_transit:
		return
	washitsu_transit = true
	player.controls_enabled = false
	SfxScript.play("rustle")
	await hud.fade_to(1.0, 0.6).finished
	if _ambient_before >= 0.0:
		room.sky_clock.ambient_scale = _ambient_before
		room.sky_clock.set_time(room.sky_clock.time)
	_ambient_before = -1.0
	room.apartment.kotatsu.set_solid(false)
	var wall_world: Vector3 = room.apartment.kotatsu.global_position + KotatsuScript.WALL_LOCAL
	player.global_position = Vector3(wall_world.x - 0.3, 0.0, wall_world.z)
	player.move_to(PlayerScript.Pose.KOTATSU_IN, player.global_position, PI * 0.5, KotatsuScript.EYE_INSIDE, [], true, PlayerScript.KOTATSU_BODY_HEIGHT, PlayerScript.KOTATSU_BODY_RADIUS)
	await hud.fade_to(0.0, 0.8).finished
	player.controls_enabled = true
	washitsu_transit = false
	hud.show_message(STAGE4["back_in_kotatsu"], 4.0)


## はしごの上り下り（浴室の入口 ⇔ ホール）。暗転して移る。
func _climb_ladder(up: bool) -> void:
	if washitsu_transit or not room.ladder_placed:
		return
	washitsu_transit = true
	player.controls_enabled = false
	SfxScript.play("rustle")
	await hud.fade_to(1.0, 0.5).finished
	if up:
		player.global_position = Vector3(0.0, room.rise_offset + 0.05, 0.85)
		player.rotation.y = 0.0
	else:
		player.global_position = Vector3(0.0, 0.05, 1.95)
		player.rotation.y = PI   # ホールの奥（+z）を向く
	player._pitch = 0.0
	player.camera.rotation.x = 0.0
	await hud.fade_to(0.0, 0.5).finished
	player.controls_enabled = true
	washitsu_transit = false
	hud.show_message(STAGE4["ladder_up"] if up else STAGE4["ladder_down"], 3.0)


# ---------------------------------------------------------------- 段階 3：松明・暗い部屋・ブレーカー

## 段階 3 の持ち物の、拡大表示用のモデル。
func _give_stage3_model(id: String) -> void:
	match id:
		"match_stick":
			_item_models[id] = Stage3Items.match_model()
		"room_key":
			_item_models[id] = Stage3Items.key_model()
		"torch":
			_item_models[id] = Stage3Items.torch_model()
		"door_knob":
			_item_models[id] = Stage3Items.knob_model()
		"fuse":
			_item_models[id] = Stage3Items.fuse_model()


## 段階 3 の持ち物を、拡大モデルつきで持ち物に入れる。
func _give_stage3(id: String) -> void:
	_give_stage3_model(id)
	add_item(id)
	progress.discover(id)


## 保存から戻すとき：ベランダに、燃える松明を置き直す（演出なし）。
func restore_thrown_torch() -> void:
	thrown_torch = BurningTorchScript.new()
	thrown_torch.position = Vector3(2.4, 0.06, -1.75)
	thrown_torch.rotation.y = 0.5
	room.exterior.add_child(thrown_torch)


## 釣りで次に釣れる、お話の持ち物（なければ ""）。ベランダのはしごを下ろしたあと、マッチ棒 → 部屋の鍵の順に、取り逃さず出る。
func _story_catch_next() -> String:
	if not room.exterior.ladder_down:
		return ""
	for id in ["match_stick", "room_key"]:
		if not items_found.has(id) and not inventory.has(id):
			return id
	# 救済：松明を捨ててしまったあと、材料が世界から消えているときだけ、また釣れる（詰み防止）
	if thrown_torch != null and not inventory.has("torch") and not power_restored:
		for id in ["match_stick", "wood_stick"]:
			if not inventory.has(id):
				return id
	return ""


func _on_story_caught(id: String) -> void:
	if id == "small_pickaxe":
		if inventory.has(id) or items_found.has(id):
			hud.show_message(STAGE5["small_have"], 4.0)
			return
		_give_stage5(id)
		hud.show_message("釣れたのは、ちいさな、ちいさなツルハシだった。……壁を叩けば、削れるのだろうか。", 6.0)
		return
	if id == "wood_stick":
		_item_models[id] = _wood_stick_model()
		add_item(id)
		hud.show_message("釣れたのは、木の棒だった。ちょうど、松明の柄になりそうだ。", 6.0)
		return
	_give_stage3(id)
	hud.show_message(STAGE3["match_caught"] if id == "match_stick" else STAGE3["key_caught"], 6.0)


## 木の棒とマッチ棒で松明を作る。
func _make_torch() -> void:
	remove_item("wood_stick")
	remove_item("match_stick")
	SfxScript.play("pop")
	_give_stage3("torch")
	select_item(inventory.find("torch"))
	hud.show_message(STAGE3["torch_made"], 5.0)


## 選んでいる物が松明なら、手元に明かりをつける（ゆらぐ）。
func _refresh_torch_light() -> void:
	var sel := selected_item()
	var on := sel == "torch" or sel == "lighter"
	if sel == "flashlight" and _flash_light == null:
		_flash_light = SpotLight3D.new()
		_flash_light.name = "FlashLight"
		_flash_light.position = Vector3(0.12, -0.12, -0.2)
		_flash_light.spot_range = 9.0
		_flash_light.spot_angle = 26.0
		_flash_light.light_energy = 3.2
		_flash_light.light_color = Color(1.0, 0.97, 0.85)
		player.camera.add_child(_flash_light)
	if _flash_light:
		_flash_light.visible = sel == "flashlight"
	_torch_base = 1.6 if sel == "torch" else 1.0
	if on and _torch_light == null:
		_torch_light = OmniLight3D.new()
		_torch_light.name = "TorchLight"
		_torch_light.position = Vector3(0.25, -0.25, -0.5)
		_torch_light.light_color = Color(1.0, 0.68, 0.32)
		_torch_light.omni_range = 4.5
		_torch_light.light_energy = 1.6
		player.camera.add_child(_torch_light)
	if _torch_light:
		_torch_light.visible = on
		_torch_light.omni_range = 4.5 if sel == "torch" else 3.0


func _update_torch_light(delta: float) -> void:
	if _torch_light and _torch_light.visible:
		_torch_t += delta
		_torch_light.light_energy = _torch_base + sin(_torch_t * 15.0) * 0.18 + sin(_torch_t * 6.1) * 0.12


## 暗い部屋でカーテンを開けると、月明かりが差す。松明を持っていたら、神の声が「危ない」と言って、窓の外へ捨てる。
func _on_curtain_changed(closed: bool) -> void:
	if room.power_on:
		return
	room.set_moonlight(not closed)
	if not closed and inventory.has("torch"):
		_throw_torch()


func _throw_torch() -> void:
	remove_item("torch")
	hud.show_message(STAGE3["torch_voice"], 4.0, "voice")
	await get_tree().create_timer(1.6).timeout
	thrown_torch = BurningTorchScript.new()
	thrown_torch.position = Vector3(2.4, 0.06, -1.75)
	thrown_torch.rotation.y = 0.5
	room.exterior.add_child(thrown_torch)
	SfxScript.play("thunk")
	hud.show_message(STAGE3["torch_thrown"], 5.0)
	progress.discover("torch_thrown")


## ブレーカーにヒューズを差した：部屋の電気がつく。松明の火は消える。
func _on_fuse_inserted() -> void:
	power_restored = true
	room.set_power(true)
	hud.show_message(STAGE3["breaker_on"], 6.0)
	progress.discover("power_back")
	if thrown_torch and is_instance_valid(thrown_torch):
		thrown_torch.extinguish()
		await get_tree().create_timer(1.2).timeout
		hud.show_message(STAGE3["torch_out"], 4.0)
	elif inventory.has("torch"):
		remove_item("torch")
		hud.show_message(STAGE3["torch_out"], 4.0)


## 九蓮宝燈を出したら、ホールのお酒のセラーのガラスが割れる。割れても、出るのは「お酒は20歳になってから。」だけ（謎解きには関わらない）。
func _check_chuuren() -> void:
	if mahjong == null or mahjong.state != "won" or not mahjong.yaku.has("九蓮宝燈"):
		return
	if not medal_given:
		medal_given = true
		_give_stage5("medal")
		progress.discover("chuuren")
		hud.show_message(STAGE5["medal_get"], 5.0)
		SfxScript.play("chime")
	if room.cellar_broken:
		return
	room.break_wine_cellar()
	progress.discover("chuuren")
	await get_tree().create_timer(1.2).timeout
	hud.show_message(LIQUOR["broken"], 6.0)


## 押入れの左の仕切りに入って、襖を閉じ、真っ暗な中に閉じこもる。出たあとは、襖は両方しまっておく。
func _enter_closet() -> void:
	var cl = room.apartment.closet
	if cl.busy or closet_hiding:
		return
	closet_hiding = true
	SfxScript.play("rustle")
	if cl.state != "futon":   # 左の仕切りをふさいでいる襖を、先に右へ寄せる
		await cl.set_state("futon").finished
	var feet: Vector3 = cl.global_position + Vector3(-cl.SLIDE_X, cl.FLOOR_T, 0.12)
	player.move_to(PlayerScript.Pose.CLOSET, feet, PI, CLOSET_EYE)
	await get_tree().create_timer(0.7).timeout
	await cl.set_state("closed").finished   # 中から襖を閉める
	hud.set_hiding(true)
	AudioSettingsScript.set_space(0.03, 900.0)
	progress.discover("closet_hide")
	hud.show_message(MESSAGES["closet_in"], 6.0)
	await get_tree().create_timer(9.0).timeout
	if closet_hiding and player.pose == PlayerScript.Pose.CLOSET:
		hud.show_message(MESSAGES["closet_quiet"], 6.0)


func _exit_closet() -> void:
	var cl = room.apartment.closet
	if cl.busy or not closet_hiding:
		return
	hud.set_hiding(false)
	SfxScript.play("rustle")
	await cl.set_state("futon").finished
	var exits := [cl.global_position + Vector3(-cl.SLIDE_X, 0.0, 0.9), cl.global_position + Vector3(-0.9, 0.0, 0.85), cl.global_position + Vector3(0.1, 0.0, 0.95), cl.global_position + Vector3(0.6, 0.0, 1.0)]   # 押入れの前の透明な板（体だけを止める）から、体の半径ぶん離れた所
	if player.leave_fixed(exits):
		closet_hiding = false
		_space_key = ""
		await get_tree().create_timer(0.9).timeout
		if not closet_hiding and cl.state == "futon" and not cl.busy:
			cl.set_state("closed")   # 出たら、襖は両方しまっておく
	else:
		hud.set_hiding(true)
		await cl.set_state("closed").finished
		hud.show_message(MESSAGES["no_way_out"])


## 秒を「m:ss」または「h:mm:ss」にする。
static func format_time(seconds: float) -> String:
	var t := int(seconds)
	if t >= 3600:
		return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]
	return "%d:%02d" % [t / 60, t % 60]


## クリアの記録（最後に出す）：クリアタイム・ベスト・発見・調べた物・手に入れた物・コイン・ノート・神の声のヒント。
## ベストは user://settings.cfg の record/best_<ルート> に残す（短いほうが良い）。
func _clear_stats_text() -> String:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var key := "best_" + clear_route
	var best := float(cfg.get_value("record", key, -1.0))
	var line := "クリアタイム　%s" % format_time(play_time)
	if best < 0.0 or play_time < best:
		if best >= 0.0:
			line += "　ベスト更新！（前のベスト %s）" % format_time(best)
		else:
			line += "　（はじめての記録）"
		if progress.enabled or OS.get_environment("TOIRE_SAVE_TEST") == "1":
			cfg.set_value("record", key, play_time)
			cfg.save(SETTINGS_PATH)
	else:
		line += "　（ベスト %s）" % format_time(best)
	var lines := PackedStringArray([
		line,
		"発見　%d / %d" % [progress.discovered.size(), progress.total()],
		"調べた物　%d / %d" % [examined.size(), maxi(total_examinable, examined.size())],
		"手に入れた物　%d / %d 種類" % [items_found.size(), ITEMS.size()],
		"集めたコイン　%d 枚" % coins_total,
		"推理ノート　%d 件" % progress.notes.size(),
		"神の声のヒント　%d / %d 回" % [progress.hints_used, progress.HINT_LIMIT],
	])
	return "\n".join(lines)


func _retry() -> void:
	progress.delete_save()
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 一時停止

## 調べられる物（id のある判定）の数を、始めに一度だけ数える。
func _count_examinable() -> void:
	var ids := {}
	for n in room.find_children("*", "CollisionObject3D", true, false):
		if n.has_meta("interact_id") and not String(n.get_meta("interact_id")).is_empty():
			ids[String(n.get_meta("interact_id"))] = true
	total_examinable = ids.size()


func _stats_text() -> String:
	var t := int(play_time)
	return "プレイ時間 %d:%02d　　調べた物 %d / %d　　発見 %d / %d" % [t / 60, t % 60, examined.size(), maxi(total_examinable, examined.size()), progress.discovered.size(), progress.total()]


## 設定の「神の声にきく」：設定を閉じて、ヒントを 1 つ出す（回数に限りがある）。
func _on_hint_requested() -> void:
	if _title != null or cleared:
		return
	_resume()
	progress.ask_hint()


func _close_notebook() -> void:
	hud.close_notebook()
	if not paused and not cleared and not reading:
		player.controls_enabled = true


func _pause() -> void:
	hud.set_hint_ask_ui(progress.hints_left(), progress.hints_on, progress.HINT_LIMIT)
	if hud.is_notebook_open():
		hud.close_notebook()
		player.controls_enabled = true
	progress.save()
	hud.set_stats(_stats_text())
	hud.show_item_zoom(null, "", "")
	paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause(true)


func _resume() -> void:
	if _title != null:   # タイトル画面の設定を閉じる（ゲームの再開ではない）
		hud.show_pause(false)
		_title.show_ui(true)
		return
	paused = false
	hud.show_pause(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 設定（身長）。user://settings.cfg に保存して、次の起動でも使う。
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		player.set_eye_height(float(cfg.get_value("player", "eye_height", PlayerScript.EYE_HEIGHT)))
	player.head_bob = bool(cfg.get_value("player", "head_bob", true))
	hud.set_head_bob_ui(player.head_bob)
	player.show_body = bool(cfg.get_value("player", "show_body", false))
	hud.set_body_ui(player.show_body)
	player.sensitivity = clampf(float(cfg.get_value("player", "sensitivity", 1.0)), PlayerScript.SENS_MIN, PlayerScript.SENS_MAX)
	hud.set_sensitivity_ui(player.sensitivity)
	hud.set_typing_ui(bool(cfg.get_value("player", "typing", true)))
	progress = ProgressScript.new()
	progress.name = "Progress"
	progress.main = self
	progress.hints_on = bool(cfg.get_value("player", "hints", true))
	add_child(progress)
	hud.set_hints_ui(progress.hints_on)
	AudioSettingsScript.load_from(cfg)
	hud.set_audio_ui({"master": AudioSettingsScript.master, "sfx": AudioSettingsScript.sfx, "ambient": AudioSettingsScript.ambient,
			"sfx_on": AudioSettingsScript.sfx_on, "ambient_on": AudioSettingsScript.ambient_on})
	player.camera.position.y = player.eye_height
	hud.set_eye_height_ui(player.eye_height)


func _on_eye_height_changed(value: float) -> void:
	player.set_eye_height(value)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("player", "eye_height", player.eye_height)
	cfg.save(SETTINGS_PATH)


func _on_head_bob_changed(on: bool) -> void:
	player.head_bob = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("player", "head_bob", on)
	cfg.save(SETTINGS_PATH)


func _on_hints_changed(on: bool) -> void:
	progress.hints_on = on
	hud.set_hint_ask_ui(progress.hints_left(), on, progress.HINT_LIMIT)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("player", "hints", on)
	cfg.save(SETTINGS_PATH)


## 保存した記録を消して、はじめからにする。
func _restart_fresh() -> void:
	progress.delete_save()
	progress.enabled = false
	_retry()


func _on_typing_changed(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("player", "typing", on)
	cfg.save(SETTINGS_PATH)


func _on_sensitivity_changed(value: float) -> void:
	player.sensitivity = clampf(value, PlayerScript.SENS_MIN, PlayerScript.SENS_MAX)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("player", "sensitivity", player.sensitivity)
	cfg.save(SETTINGS_PATH)


func _on_body_visible_changed(on: bool) -> void:
	player.show_body = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("player", "show_body", on)
	cfg.save(SETTINGS_PATH)


func _on_audio_changed(key: String, value: Variant) -> void:
	AudioSettingsScript.set_value(key, value)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	AudioSettingsScript.save_to(cfg)
	cfg.save(SETTINGS_PATH)


func _quit() -> void:
	progress.save()
	get_tree().quit()


# ---------------------------------------------------------------- 入力設定

func _setup_input_map() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_back", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("pause", [KEY_ESCAPE])
	_add_key_action("crouch", [KEY_C])
	_add_key_action("action", [KEY_E])
	_add_key_action("use_item", [KEY_F])
	_add_key_action("message_log", [KEY_H])
	_add_key_action("notebook", [KEY_N])
	_add_key_action("eye_down", [KEY_BRACKETLEFT])
	_add_key_action("eye_up", [KEY_BRACKETRIGHT])
	_add_key_action("item_1", [KEY_1])
	_add_key_action("item_2", [KEY_2])
	_add_key_action("item_3", [KEY_3])
	_add_key_action("item_4", [KEY_4])
	_add_key_action("item_5", [KEY_5])
	_add_key_action("item_6", [KEY_6])
	_add_key_action("item_7", [KEY_7])
	_add_key_action("item_8", [KEY_8])
	_add_key_action("inspect_item", [KEY_Q])
	_add_key_action("drop_item", [KEY_G])
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact", click)


func _add_key_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
