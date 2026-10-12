extends Node3D
## ゲーム進行（開始→探索→ドライバー取得→ドア修理→脱出）と一時停止を管理する。
## 再プレイはシーンを読み込み直すので、ドライバー・ドア・所持品はすべて初期状態に戻る。

const RoomScript := preload("res://scripts/room.gd")
const PlayerScript := preload("res://scripts/player.gd")
const HudScript := preload("res://scripts/hud.gd")

const MESSAGES := {
	"start": "……気がつくと、ユニットバスに閉じ込められていた。ドアを開けて外に出よう。",
	"toilet": "普通の便器だ。水は流れるが、ここから出られるわけではない。",
	"bathtub": "空っぽの浴槽。乾いていて、何も入っていない。",
	"bathtub_water": "浴槽に水がたまっている。",
	"bathtub_wet": "空の浴槽。底がまだ濡れている。",
	"sink": "小さな洗面台。……下に何か落ちている？",
	"vent": "換気口。格子の奥は暗く、よく見えない。",
	"poster": "水道修理の広告だ。連絡先は管理会社……スマホは部屋に置いてきた。",
	"bath_powder": "ユブロマン。ゆずの香りの入浴剤。今はのんびり浸かっている場合じゃない。",
	"paper_holder": "いつものトイレットペーパー。ここだけは平常運転だ。",
	"spare_roll": "『明日もある』。今日の分は、なんとかしてほしい。",
	"toilet_cleaner": "『無かったことに』。閉じ込められた件にも効くだろうか。",
	"plunger": "ラバーカップ。ブラシと妙にきれいに並んでいる。",
	"toilet_brush": "トイレブラシ。ここでの仕事には慣れていそうだ。",
	"vent_sticker": "『点検済。異常なし。たぶん。』……たぶん？",
	"face_wash": "洗顔料。泡立ちがいいらしい。",
	"toner": "化粧水。ほとんど減っていない。",
	"cotton_swabs": "綿棒。ぎっしり詰まっている。",
	"driver": "ドライバーを手に入れた。",
	"door_locked": "ドアノブが空回りする。開かない。",
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
	"flush": "左クリック：水を流す",
}

## E キーで変わる姿勢の案内
const ACTION_PROMPTS := {
	"sit": "E：座る",
	"stand_up": "E：立つ",
	"tub_enter": "E：浴槽に入る",
	"tub_exit": "E：浴槽から出る",
}

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

var has_driver := false
var door_open := false
var cleared := false
var paused := false

var room: RoomScript
var player: PlayerScript
var hud: HudScript


func _ready() -> void:
	# メインは一時停止中も Esc を受け取れるようにする。プレイヤーと部屋は止める。
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_setup_input_map()

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
	player.crouch_blocked.connect(func() -> void: hud.show_message(MESSAGES["no_headroom"]))

	room.exit_area.body_entered.connect(_on_exit_body_entered)

	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)
	hud.resume_pressed.connect(_resume)
	hud.quit_pressed.connect(_quit)
	hud.retry_pressed.connect(_retry)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message(MESSAGES["start"], 5.0)


func _process(_delta: float) -> void:
	if paused or cleared:
		hud.set_prompt("")
		return
	var focused := player.get_focused()
	var parts := []
	var click := _prompt_for(focused)
	if not click.is_empty():
		parts.append(click)
	var action := _action_for(focused)
	if not action.is_empty():
		parts.append(ACTION_PROMPTS[action])
	hud.set_prompt("　／　".join(parts))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("action"):
		get_viewport().set_input_as_handled()
		if not paused and not cleared:
			do_action()
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if cleared:
			return
		if paused:
			_resume()
		else:
			_pause()


# ---------------------------------------------------------------- 姿勢（座る・浴槽）

## 今 E キーでできること（ACTION_PROMPTS のキー）。なければ空。
func _action_for(target: Object) -> String:
	match player.pose:
		PlayerScript.Pose.SEATED:
			return "stand_up"
		PlayerScript.Pose.IN_TUB:
			return "tub_exit"
		PlayerScript.Pose.TRANSITION:
			return ""
	if target == null:
		return ""
	var id := String(target.get_meta("interact_id", ""))
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
		"stand_up":
			if player.leave_fixed(SEAT_EXITS):
				room.toilet.occupied = false
			else:
				hud.show_message(MESSAGES["no_way_out"])
		"tub_enter":
			var feet: Vector3 = room.bathtub.to_global(TUB_FEET_LOCAL)
			if player.is_space_free(feet, TUB_BODY_HEIGHT):
				player.enter_fixed(PlayerScript.Pose.IN_TUB, feet, TUB_YAW, TUB_EYE)
		"tub_exit":
			if not player.leave_fixed(TUB_EXITS):
				hud.show_message(MESSAGES["no_way_out"])


# ---------------------------------------------------------------- 調べる

func _prompt_for(target: Object) -> String:
	if target == null:
		return ""
	var id := String(target.get_meta("interact_id", ""))
	var fixture: Object = target.get_meta("fixture") if target.has_meta("fixture") else null
	if fixture:
		return PROMPTS.get(fixture.get_prompt(id), "")
	match id:
		"":
			return ""
		"driver":
			return PROMPT_PICKUP
		"door":
			return PROMPT_REPAIR if has_driver else PROMPT_EXAMINE
		_:
			return PROMPT_EXAMINE


func _on_interact_requested(target: Object) -> void:
	if paused or cleared or target == null:
		return
	var id := String(target.get_meta("interact_id", ""))
	var fixture: Object = target.get_meta("fixture") if target.has_meta("fixture") else null
	if fixture:
		# 便器・浴槽・蛇口など状態を持つ設備は、その設備が操作し、表示する説明のキーを返す
		var key: String = fixture.interact(id)
		if not key.is_empty():
			hud.show_message(MESSAGES[key])
		return
	match id:
		"sink", "vent", "poster", "bath_powder", \
		"paper_holder", "spare_roll", "toilet_cleaner", "plunger", "toilet_brush", "vent_sticker", \
		"face_wash", "toner", "cotton_swabs":
			hud.show_message(MESSAGES[id])
		"driver":
			if has_driver:
				return
			has_driver = true
			room.remove_driver()
			hud.set_inventory("ドライバー")
			hud.show_message(MESSAGES["driver"])
		"door":
			if door_open:
				return
			if has_driver:
				door_open = true
				room.open_door()
				hud.show_message(MESSAGES["door_fixed"])
			else:
				hud.show_message(MESSAGES["door_locked"])


# ---------------------------------------------------------------- 脱出

func _on_exit_body_entered(body: Node3D) -> void:
	if body != player or not door_open or cleared:
		return
	cleared = true
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_clear()


func _retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- 一時停止

func _pause() -> void:
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
