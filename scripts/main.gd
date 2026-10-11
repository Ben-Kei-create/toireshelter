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
	"mirror": "くもった鏡。疲れた顔の自分がぼんやり映っている。",
	"sink": "洗面台。蛇口をひねっても特に何も起きない。……下に何か落ちている？",
	"driver": "ドライバーを手に入れた。",
	"door_locked": "ドアノブが空回りする。開かない。",
	"door_fixed": "ドライバーでドアノブのネジを締め直した。……ドアが開いた！",
}

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
	hud.set_prompt(_prompt_for(player.get_focused()))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if cleared:
			return
		if paused:
			_resume()
		else:
			_pause()


# ---------------------------------------------------------------- 調べる

func _prompt_for(target: Object) -> String:
	if target == null:
		return ""
	var id := String(target.get_meta("interact_id", ""))
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
	match id:
		"toilet", "bathtub", "mirror", "sink":
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
