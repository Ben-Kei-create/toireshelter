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
const IntercomScript := preload("res://scripts/intercom.gd")
const CorkGunScript := preload("res://scripts/cork_gun.gd")
const MahjongGame := preload("res://scripts/mahjong_game.gd")
const ClosetScriptRef := preload("res://scripts/closet.gd")
const RecordPlayerRef := preload("res://scripts/record_player.gd")
const MeshKit := preload("res://scripts/mesh_kit.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const BooksScript := preload("res://scripts/books.gd")
const CorridorScript := preload("res://scripts/corridor.gd")

const MESSAGES := {
	"start": "……気がつくと、ユニットバスに閉じ込められていた。ここから出て、部屋の外へ出なければ。",
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
	"cabinet_locked": "鏡の扉は開かない。右端に溝付きの留め具がある。",
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
	"bath_light_purple": "カチッ……電球がちらついて、トイレが紫色の光に包まれた。",
	"bath_light_on_purple": "カチッ。トイレが紫色にともった。",
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
	"game_cover_1": "ソフトのケース。『下北沢、午前二時』。赤い月の下の路地に、女の子がひとり。……架空のゲームだ。",
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
	"fusuma_right": "左クリック：襖を右へ寄せる（ふとんを見る）",
	"fusuma_left": "左クリック：襖を左へ寄せる（つかみどりを見る）",
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
}

## E キーで変わる姿勢の案内
const ACTION_PROMPTS := {
	"sit": "E：座る",
	"stand_up": "E：立つ",
	"tub_enter": "E：浴槽に入る",
	"tub_exit": "E：浴槽から出る",
	"vent_enter": "E：換気口へ入る",
	"duct_back": "E：浴室へ戻る",
	"balcony_down": "E：ベランダへ降りる",
	"kotatsu_sit": "E：こたつに座る",
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

const TUB_TARGETS := ["bathtub", "bath_plug", "bath_faucet", "tub_note"]   # 入浴剤を使える照準先（浴槽のどこか）

## 調べたときに鳴らす効果音（fixture のない対象）
const INTERACT_SFX := {"guitar": "strum", "fridge": "thunk", "kitchen_stove": "click", "phone_mobile": "click", "kitchen_sink": "click", "cards": "page", "card_box": "click", "dice": "click", "cup": "click", "tissue": "rustle", "magazines": "page", "teddy": "rustle", "standee": "click", "toilet_slippers": "rustle", "shoes": "click", "clothes": "rustle", "bag": "rustle", "dumbbell": "clunk", "bottle": "click", "tv_remote": "beep", "rug": "rustle"}
const CLEAR_TITLES := {"legit": "正規ルートで脱出", "shortcut": "裏技ルートで脱出"}
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
var paused := false
var play_time := 0.0               # 一時停止中を除くプレイ時間（秒）。空模様に使う
var kotatsu_seat := 0              # 座っている（入っている）こたつの座布団（KotatsuScript.SEATS の番号）
var peeping := false               # のぞき穴の画面が開いている
var reading := false               # 本を読む画面が開いている
const TISSUE_SHEETS := 12
var coin_count := 0                # 持っている UFOコインの枚数
var tissue_pulled := 0             # ティッシュを引いた回数
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
	_load_settings()
	room.apartment.intercom.front_door = room.front_door
	room.apartment.intercom.notice.connect(func(text: String) -> void: hud.show_message(text, 5.0))
	room.apartment.ufo_catcher.coin_check = spend_coin
	room.toilet.coin_taken.connect(add_coin)
	room.apartment.cellar.descend_requested.connect(_descend)
	room.apartment.basement.ascend_requested.connect(_ascend)
	room.apartment.cellar.stairs_revealed.connect(func() -> void: hud.show_message(MESSAGES["stairs_revealed"], 5.0))
	room.apartment.record_player.disc_set.connect(func() -> void: remove_item("record_disc"))
	fishing = FishingScript.new()
	fishing.name = "Fishing"
	room.add_child(fishing)
	fishing.player = player
	fishing.coin_caught.connect(func() -> void: add_coin(1))
	fishing.notice.connect(func(text: String) -> void: hud.show_message(text))
	hud.set_catch_text(fishing.collection_text())
	fishing.collection_changed.connect(hud.set_catch_text)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message(MESSAGES["start"], 5.0)


func _process(_delta: float) -> void:
	var carried: String = room.apartment.cellar.carrying_name
	hud.set_carry("運んでいる：%s（冷蔵庫の中を狙って、左クリックで入れる）" % carried if not carried.is_empty() else "")
	if not paused and not cleared:
		play_time += _delta
		room.sky_clock.set_time(play_time)
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
	if not click.is_empty():
		parts.append(click)
	var use := _use_prompt(focused)
	if not use.is_empty():
		parts.append(use)
	var action := _action_for(focused)
	if not action.is_empty():
		parts.append(ACTION_PROMPTS[action])
	hud.set_prompt("　／　".join(parts))


## ウィンドウが選ばれなくなったら自動で一時停止（ゲーム中に別のウィンドウへ移ったとき、勝手に進まないように）
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not paused and not cleared and not mj_playing and not gaming and not peeping:
		_pause()


func _unhandled_input(event: InputEvent) -> void:
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
			select_item(0)
			return
		if event.is_action_pressed("item_2"):
			select_item(1)
			return
		if event.is_action_pressed("item_3"):
			select_item(2)
			return
		if event.is_action_pressed("item_4"):
			select_item(3)
			return
		if event.is_action_pressed("item_5"):
			select_item(4)
			return
		if event.is_action_pressed("item_6"):
			select_item(5)
			return
		if event.is_action_pressed("item_7"):
			select_item(6)
			return
		if event.is_action_pressed("item_8"):
			select_item(7)
			return
		if event.is_action_pressed("inspect_item"):
			toggle_zoom()
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
	hud.show_message("パンッ！ コルクが飛んでいって、はね返った。")


# ---------------------------------------------------------------- ゲームソフトの入れ替え

const GAME_NAMES := ["ラケット対戦（PONG）", "ブロック崩し（BLOCKS）", "へび（SNAKE）", "よけゲー（DODGE）", "ラベルのはがれたディスク"]


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


func _phone_dial() -> void:
	var which: String = PHONE_CALLS[phone_index % PHONE_CALLS.size()]
	phone_index += 1
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
	player.controls_enabled = false
	if mahjong == null:
		mahjong = MahjongGame.new()
	mahjong.start()
	mj_cursor = 13 if mahjong.state == "playing" else 0
	SfxScript.play("click")
	hud.show_message(MESSAGES["mj_start"], 3.0)
	_refresh_mahjong()


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


func _show_reader_page() -> void:
	hud.show_reader(_reader_title, _reader_pages[_reader_page], _reader_cover, _reader_tint, _reader_page, _reader_pages.size())


func _close_reader() -> void:
	reading = false
	hud.hide_reader()
	player.controls_enabled = true


# ---------------------------------------------------------------- 姿勢（座る・浴槽）

## 今 E キーでできること（ACTION_PROMPTS のキー）。なければ空。
func _action_for(target: Object) -> String:
	match player.pose:
		PlayerScript.Pose.SEATED:
			return "stand_up"
		PlayerScript.Pose.IN_TUB:
			# 浴槽の中から換気口を狙うと「換気口へ入る」
			if target and String(target.get_meta("interact_id", "")) == "vent":
				return "vent_enter"
			return "tub_exit"
		PlayerScript.Pose.TRANSITION:
			return ""
		PlayerScript.Pose.LYING:
			return "get_up"
		PlayerScript.Pose.KOTATSU_SEAT:
			return "kotatsu_stand"
		PlayerScript.Pose.KOTATSU_IN:
			return "kotatsu_out"
		PlayerScript.Pose.DUCT:
			var p := player.global_position
			if Vector2(p.x - VENT_MOUTH.x, p.z - VENT_MOUTH.z).length() < DUCT_BACK_RANGE:
				return "duct_back"
			if p.z < ExteriorScript.DUCT_EXIT_EDGE_Z and p.x > ExteriorScript.DUCT_B.position.x:
				return "balcony_down"
			return ""
	if target == null:
		return ""
	var id := String(target.get_meta("interact_id", ""))
	if id == "kotatsu" and player.pose == PlayerScript.Pose.WALK:
		return "kotatsu_sit"
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
			player.enter_fixed(PlayerScript.Pose.SEATED, SEAT_FEET, SEAT_YAW, SEAT_EYE)
		"kotatsu_sit":
			SfxScript.play("rustle")
			kotatsu_seat = KotatsuScript.nearest_seat(player.global_position)
			var seat: Dictionary = KotatsuScript.SEATS[kotatsu_seat]
			player.enter_fixed(PlayerScript.Pose.KOTATSU_SEAT, seat.feet, seat.yaw, KotatsuScript.EYE_SEATED)
		"sleep":
			SfxScript.play("rustle")
			player.enter_fixed(PlayerScript.Pose.LYING, BED_FEET, BED_YAW, BED_EYE)
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
		"kotatsu_out":
			var seat2: Dictionary = KotatsuScript.SEATS[kotatsu_seat]
			room.apartment.kotatsu.set_solid(true)
			SfxScript.play("rustle")
			player.move_to(PlayerScript.Pose.KOTATSU_SEAT, seat2.feet, seat2.yaw, KotatsuScript.EYE_SEATED)
		"stand_up":
			if player.leave_fixed(SEAT_EXITS):
				room.toilet.occupied = false
				if not room.toilet_panel.mode.is_empty():
					hud.show_message(MESSAGES["washlet_stood_up"])
				room.toilet_panel.stop()   # 立つと操作パネルは止まる
			else:
				hud.show_message(MESSAGES["no_way_out"])
		"tub_enter":
			var feet: Vector3 = room.bathtub.to_global(TUB_FEET_LOCAL)
			if player.is_space_free(feet, TUB_BODY_HEIGHT):
				player.enter_fixed(PlayerScript.Pose.IN_TUB, feet, TUB_YAW, TUB_EYE)
		"tub_exit":
			if not player.leave_fixed(TUB_EXITS):
				hud.show_message(MESSAGES["no_way_out"])
		"vent_enter":
			room.open_vent()
			player.move_to(PlayerScript.Pose.DUCT, ExteriorScript.DUCT_START, DUCT_YAW, PlayerScript.DUCT_EYE_HEIGHT,
					[VENT_BELOW, VENT_MOUTH], true, PlayerScript.DUCT_BODY_HEIGHT, PlayerScript.DUCT_BODY_RADIUS)
		"duct_back":
			var tub_feet: Vector3 = room.bathtub.to_global(TUB_FEET_LOCAL)
			player.move_to(PlayerScript.Pose.IN_TUB, tub_feet, TUB_YAW, TUB_EYE, [VENT_MOUTH, VENT_BELOW])
		"balcony_down":
			if player.leave_fixed(BALCONY_LANDINGS, [DUCT_EXIT_MOUTH]):
				route_duct = true
			else:
				hud.show_message(MESSAGES["no_way_out"])


# ---------------------------------------------------------------- 調べる

func _prompt_for(target: Object) -> String:
	if target == null:
		return ""
	var id := String(target.get_meta("interact_id", ""))
	var fixture: Object = target.get_meta("fixture") if target.has_meta("fixture") else null
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
		"driver", "spare_roll", "bath_powder", "fishing_rod", "cork_gun", "mahjong", "record_disc":
			return PROMPT_PICKUP
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
		_:
			return PROMPT_EXAMINE


func _on_interact_requested(target: Object) -> void:
	if paused or cleared or reading or target == null:
		return
	var id := String(target.get_meta("interact_id", ""))
	var fixture: Object = target.get_meta("fixture") if target.has_meta("fixture") else null
	# 床下の食べ物を持っているとき、開けた冷蔵室の中を狙うと、棚に入れる（全部入れると階段が現れる）
	var cellar_c = room.apartment.cellar
	if not cellar_c.carrying_id.is_empty() and id == "fridge_inside":
		var name_c: String = cellar_c.carrying_name
		if room.apartment.kitchen.put_food(cellar_c.carrying_id):
			var left_after: int = cellar_c.FOODS.size() - cellar_c.stored.size() - 1
			hud.show_message(MESSAGES["fridge_put"].replace("{food}", name_c).replace("{left}", str(left_after)))
			cellar_c.food_stored()
		return
	if fixture:
		# 便器・浴槽・蛇口など状態を持つ設備は、その設備が操作し、表示する説明のキーを返す
		var key: String = fixture.interact(id)
		if not key.is_empty():
			var text: String = MESSAGES[key]
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
		"sink", "vent", "poster", \
		"toilet_cleaner", "plunger", "toilet_brush", "vent_sticker", "bath_bucket", "shampoo", "rinse", "razor", \
		"face_wash", "toner", "cotton_swabs", "tub_note", "towel_scratch", "shelf_note", "tank_note", \
		"kitchen_sink", "kitchen_stove", "fridge", "guitar", "taxidermy", "phone_mobile", \
		"life_paper_02", "life_paper_07", "bed", "microwave", "game_cover_1", "game_cover_2", "game_cover_3", "game_cover_4", "record_jacket_1", "record_jacket_2", "record_jacket_3", "record_jacket_4", "game_cover_5", "game_cover_6", "game_cover_7", "book_new_1", "book_new_2", "book_new_3", "book_new_4", "book_new_5", "book_new_6", "book_new_7", "book_new_8", "rug", "card_box", "magazines", "teddy", "clothes", "dumbbell", "bottle", "bag", "shoes", "toilet_slippers", "standee":
			hud.show_message(MESSAGES[id])
		"phone_black":
			_phone_dial()
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
		"kotatsu":
			match player.pose:
				PlayerScript.Pose.KOTATSU_SEAT:
					var seat3: Dictionary = KotatsuScript.SEATS[kotatsu_seat]
					room.apartment.kotatsu.set_solid(false)   # 中を這って動けるように
					SfxScript.play("rustle")
					player.move_to(PlayerScript.Pose.KOTATSU_IN, seat3.inside, seat3.yaw, KotatsuScript.EYE_INSIDE, [], true, PlayerScript.KOTATSU_BODY_HEIGHT, PlayerScript.KOTATSU_BODY_RADIUS)
					hud.show_message(MESSAGES["kotatsu_inside"])
				PlayerScript.Pose.KOTATSU_IN:
					hud.show_message(MESSAGES["kotatsu_inside"])
				_:
					hud.show_message(MESSAGES["kotatsu_look"])
		"door":
			if door_open:
				return
			hud.show_message(MESSAGES["door_loose"] if has_driver else MESSAGES["door_locked"])


# ---------------------------------------------------------------- 持ち物

## 持ち物に加える（同じ物は重複しない）。加えた物を選択する。
func add_item(id: String) -> bool:
	if inventory.has(id):
		return false
	SfxScript.play("pop")
	inventory.append(id)
	select_item(inventory.size() - 1)
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
	if i < 0 or i >= inventory.size():
		selected = -1 if inventory.is_empty() else clampi(i, 0, inventory.size() - 1)
	else:
		selected = i
	var names := []
	for id in inventory:
		names.append(item_name(id))
	hud.set_inventory(names, selected)
	if hud.is_zoom_open():
		_show_zoom()


## UFOコインを n 枚ふやす（持ち物には1つの欄に「×枚数」でまとめる）。
func add_coin(n := 1) -> void:
	coin_count += n
	if not inventory.has("ufo_coin"):
		_item_models["ufo_coin"] = FishingScript.coin_model()
		add_item("ufo_coin")
	else:
		select_item(inventory.find("ufo_coin"))


## クレーンゲームで1枚使う。なければ false。
func spend_coin() -> bool:
	if coin_count <= 0:
		return false
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
	hud.show_item_zoom(_item_models.get(id), item_name(id), desc)


## F の案内（照準の対象に選んだ物が使えるときだけ）。
func _use_prompt(target: Object) -> String:
	var id := selected_item()
	if id == "cork_gun" and player.pose != PlayerScript.Pose.TRANSITION:
		return "F：コルク銃を撃つ"
	if id == "mahjong" and player.pose == PlayerScript.Pose.KOTATSU_IN:
		return "F：一人麻雀を打つ"
	if id.is_empty() or target == null or player.pose == PlayerScript.Pose.TRANSITION:
		return ""
	var tid := String(target.get_meta("interact_id", ""))
	if id == "driver" and tid in ["mirror_door", "mirror_lock"] and room.mirror_cabinet.locked:
		return "F：ドライバーで留め具を外す"
	if (id == "driver" and tid == "door" and not door_open) \
			or (id == "spare_roll" and tid in ["paper_holder", "paper_cover"] and not room.supplies.has_paper) \
			or (id == "bath_powder" and not powder_used and tid in TUB_TARGETS):
		return "F：%sを使う" % item_name(id)
	return ""


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
		_clear("legit" if route_duct else "shortcut")
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
		"duct": [0.28, 5000.0], "balcony": [0.02, 20000.0]}
var _space_key := ""


func _update_space() -> void:
	var key := region
	if player.pose == PlayerScript.Pose.KOTATSU_IN:
		key = "kotatsu"
	if key == _space_key or key.is_empty():
		return
	_space_key = key
	var sp: Array = SPACES.get(key, [0.07, 20000.0]) if key != "kotatsu" else [0.03, 900.0]
	AudioSettingsScript.set_space(sp[0], sp[1])


## 足元の素材（足音用）。
func _surface_at(p: Vector3) -> String:
	match _region_of(p) if not _region_of(p).is_empty() else region:
		"bath":
			return "tile"
		"corridor":
			return "concrete"
		"duct", "balcony":
			return "metal"
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
	hud.show_clear(CLEAR_TITLES[route])


func _retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 一時停止

func _pause() -> void:
	hud.show_item_zoom(null, "", "")
	paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_pause(true)


func _resume() -> void:
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
	_add_key_action("item_1", [KEY_1])
	_add_key_action("item_2", [KEY_2])
	_add_key_action("item_3", [KEY_3])
	_add_key_action("item_4", [KEY_4])
	_add_key_action("item_5", [KEY_5])
	_add_key_action("item_6", [KEY_6])
	_add_key_action("item_7", [KEY_7])
	_add_key_action("item_8", [KEY_8])
	_add_key_action("inspect_item", [KEY_Q])
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
