extends Node
## 初見テスト用の行動ログ。環境変数 TOIRE_PLAYTEST=1 で有効（ふつうの遊びでは何も書かない）。
## user://playtest/ に、1 回の遊びごとに 1 ファイル（JSON Lines）。1 行 = 1 つの出来事：{t: 経過秒, e: 種類, ...}。
## 記録するもの：発見・持ち物・調べた対象・読んだメッセージの冒頭・放置・同じ対象の反復・やめた時点。
## 何を「聞く」かより、何を「した」かを見るためのもの（docs/playtest_sheet.md）。

var _file: FileAccess
var _t := 0.0
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
	if _t - _last_input_t > 25.0 and not _idle_reported:
		_idle_reported = true
		log_event("idle", {"seconds": int(_t - _last_input_t)})


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		if event.is_pressed():
			_last_input_t = _t
			_idle_reported = false


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
