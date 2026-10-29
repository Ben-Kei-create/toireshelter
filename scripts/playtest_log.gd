extends Node
## 初見テスト用の行動ログ。環境変数 TOIRE_PLAYTEST=1 で有効（ふつうの遊びでは何も書かない）。
## user://playtest/ に、1 回の遊びごとに 1 ファイル（JSON Lines）。1 行 = 1 つの出来事：{t: 経過秒, e: 種類, ...}。
## 記録するもの：発見・持ち物・調べた対象・読んだメッセージの冒頭・放置・同じ対象の反復・やめた時点。
## 何を「聞く」かより、何を「した」かを見るためのもの（docs/playtest_sheet.md）。

# 「放置」の判定：これだけの間、操作がなければ放置。マウスの見回し・スティックも操作に数える。
# 小さな揺れ（机の振動・スティックの遊び）で放置が解除され続けないよう、しきい値を設ける。
const IDLE_SECONDS := 25.0
const MOUSE_ACTIVE_PX := 30.0       # MOUSE_WINDOW 秒のうちに、合わせてこれだけ動かしたら操作した（揺れ・触れただけは届かない）
const MOUSE_WINDOW := 2.0
const STICK_DEADZONE := 0.3         # スティックは、これより倒していたら操作した（倒しっぱなしの歩きも含む）
const MOVE_ACTIONS := ["move_forward", "move_back", "move_left", "move_right"]

var _file: FileAccess
var _t := 0.0
var _mouse_accum := 0.0
var _mouse_window_start := 0.0
var _last_input_t := 0.0
var _idle_reported := false
var _interact_counts := {}
var enabled := false


static func wanted() -> bool:
	return OS.get_environment("TOIRE_PLAYTEST") == "1"


func _ready() -> void:
	enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://playtest"))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_file = FileAccess.open("user://playtest/session_%s.jsonl" % stamp, FileAccess.WRITE)
	log_event("start", {"version": ProjectSettings.get_setting("application/config/version", "dev")})


func _process(delta: float) -> void:
	_t += delta
	if _holding_input():
		_mark_active()
	if _t - _last_input_t > IDLE_SECONDS and not _idle_reported:
		_idle_reported = true
		log_event("idle", {"seconds": int(_t - _last_input_t)})


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			_mark_active()
	elif event is InputEventMouseMotion:
		# 画面の実ピクセルで測る（relative はウィンドウの拡大縮小で大きさが変わるので使わない）
		var px := (event as InputEventMouseMotion).screen_relative.length()
		if _t - _mouse_window_start > MOUSE_WINDOW:
			_mouse_window_start = _t
			_mouse_accum = 0.0
		_mouse_accum += px
		if _mouse_accum >= MOUSE_ACTIVE_PX:
			_mouse_accum = 0.0
			_mark_active()
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE:
			_mark_active()


func _mark_active() -> void:
	_last_input_t = _t
	_idle_reported = false


## キーやスティックを押し（倒し）たままの歩き・見回しは、新しい入力の出来事が来ないので、毎フレーム状態を見る。
func _holding_input() -> bool:
	for a in MOVE_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	for device in Input.get_connected_joypads():
		for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			if absf(Input.get_joy_axis(device, axis)) >= STICK_DEADZONE:
				return true
	return false


func log_event(kind: String, data := {}) -> void:
	if not enabled or _file == null:
		return
	var row := {"t": snappedf(_t, 0.1), "e": kind}
	row.merge(data)
	_file.store_line(JSON.stringify(row))
	_file.flush()


## 調べた対象を数える（同じ対象を何度も調べているときは、迷っているしるし）。
func interacted(id: String) -> void:
	_interact_counts[id] = int(_interact_counts.get(id, 0)) + 1
	var n: int = _interact_counts[id]
	if n == 1 or n == 5 or n == 10 or n == 20:
		log_event("interact", {"id": id, "n": n})


func _exit_tree() -> void:
	log_event("end")
