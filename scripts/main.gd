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
	"ufo_miss": "アームが降りて……景品をつかみそこねた。",
	"ufo_win": "景品をつかんだ。取り出し口に落ちた。持ち帰れはしないらしい。",
	"ufo_empty": "景品は、もうない。",
	"life_paper_02": "古い映画の再上映。半券を捨てずに取ってある。",
	"life_paper_07": "石好きの会。ここなら話が合いそうだ。",
	"shelf_note": "棚の裏に小さな紙が貼ってある。『下からなら見える。』",
	"tank_note": "タンクの下の壁に小さな紙。『しゃがむと、いろいろ見える。』",
	"door_fixed": "ドライバーでドアノブのネジを締め直した。……ドアが開いた！",
	"no_headroom": "頭上が狭くて、ここでは立ち上がれない。",
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
}

## 持ち物（拾える物）。最大2つ。1・2 キーは取った順
const ITEMS := {
	"driver": {"name": "ドライバー", "desc": "赤橙の柄のドライバー。先はプラス。"},
	"spare_roll": {"name": "予備ロール", "desc": "包装されたトイレットペーパー。『明日もある』。"},
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
}

const TUB_TARGETS := ["bathtub", "bath_plug", "bath_faucet", "tub_note"]   # 入浴剤を使える照準先（浴槽のどこか）

## 調べたときに鳴らす効果音（fixture のない対象）
const INTERACT_SFX := {"guitar": "strum", "phone_black": "ring", "fridge": "thunk", "kitchen_stove": "click", "phone_mobile": "click", "kitchen_sink": "click"}
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
var reading := false               # 本を読む画面が開いている
var _reader_pages: Array = []
var _reader_page := 0
var _reader_title := ""
var _reader_cover: Texture2D
var _reader_tint := Color.WHITE
var _reader_opened_frame := -1

var room: RoomScript
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

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message(MESSAGES["start"], 5.0)


func _process(_delta: float) -> void:
	if not paused and not cleared:
		play_time += _delta
		room.sky_clock.set_time(play_time)
	if paused or cleared or reading:
		hud.set_prompt("")
		return
	var focused := player.get_focused()
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


func _unhandled_input(event: InputEvent) -> void:
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
	match id:
		"":
			return ""
		"driver", "spare_roll", "bath_powder":
			return PROMPT_PICKUP
		"door":
			return PROMPT_EXAMINE
		"kotatsu":
			return PROMPTS["kotatsu_enter"] if player.pose == PlayerScript.Pose.KOTATSU_SEAT else PROMPT_EXAMINE
		_:
			return PROMPT_EXAMINE


func _on_interact_requested(target: Object) -> void:
	if paused or cleared or reading or target == null:
		return
	var id := String(target.get_meta("interact_id", ""))
	var fixture: Object = target.get_meta("fixture") if target.has_meta("fixture") else null
	if fixture:
		# 便器・浴槽・蛇口など状態を持つ設備は、その設備が操作し、表示する説明のキーを返す
		var key: String = fixture.interact(id)
		if not key.is_empty():
			hud.show_message(MESSAGES[key])
		return
	if not fixture and INTERACT_SFX.has(id):
		SfxScript.play(INTERACT_SFX[id])
	match id:
		"sink", "vent", "poster", \
		"toilet_cleaner", "plunger", "toilet_brush", "vent_sticker", "bath_bucket", "shampoo", "rinse", "razor", \
		"face_wash", "toner", "cotton_swabs", "tub_note", "towel_scratch", "shelf_note", "tank_note", \
		"kitchen_sink", "kitchen_stove", "fridge", "guitar", "taxidermy", "phone_black", "phone_mobile", \
		"life_paper_02", "life_paper_07":
			hud.show_message(MESSAGES[id])
		"driver":
			if has_driver:
				return
			has_driver = true
			_item_models["driver"] = room.driver_node.get_node("Visual").duplicate()
			room.remove_driver()
			add_item("driver")
			hud.show_message(MESSAGES["driver"])
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


func item_name(id: String) -> String:
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
			player.leave_crawl()
			room.apartment.kotatsu.set_solid(true)
			SfxScript.play("rustle")
			hud.show_message(MESSAGES["kotatsu_exit"])
	region = _region_of(player.global_position)
	if region.is_empty() or region == _last_region:
		return
	# 玄関ドアから廊下へ出た瞬間に、通ってきた経路で判定する（自室・ホールに入っただけではクリアしない）
	if region == "corridor" and _last_region == "hall":
		_clear("legit" if route_duct else "shortcut")
	_last_region = region


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
	_add_key_action("item_1", [KEY_1])
	_add_key_action("item_2", [KEY_2])
	_add_key_action("item_3", [KEY_3])
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
