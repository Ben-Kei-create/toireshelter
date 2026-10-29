extends SceneTree
## 初見テストの行動ログ：「放置」の判定。
## 入力は Input.parse_input_event で実際の入力経路を通し、時間はログの _process を手で進めて測る（25 秒を実時間で待たない）。
## - 見回し（マウス移動・スティック）、歩きのキーを押しっぱなし → 放置にならない
## - 本当に何もしない → 放置になる
## - 小さな揺れ（マウスの 1px、スティックの遊び）→ 放置は解除されない
## 実行: Godot --headless --path . --script res://tests/playtest_idle_test.gd

const LogScript := preload("res://scripts/playtest_log.gd")
const STEP := 0.25

var _failures := 0
var _main: Node


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	_main = current_scene
	_main.credits_enabled = false

	var pl = _new_log()
	await _advance(pl, 30.0, func(_i): pass)
	_check(pl._idle_reported, "何もしないと、25 秒で放置になる")

	pl = _new_log()
	var looked := await _advance(pl, 40.0, func(_i): _mouse(Vector2(6.0, 1.0)))
	_check(not looked, "ゆっくり見回している間（1 秒に 24px、40 秒）は、放置にならない")

	pl = _new_log()
	var slow := await _advance(pl, 40.0, func(i): if i % 4 == 0: _mouse(Vector2(0.0, 32.0)))
	_check(not slow, "1 秒に 1 回、大きく見回すだけでも、放置にならない")

	pl = _new_log()
	await _advance(pl, 30.0, func(_i): _mouse(Vector2(1.0, 0.5)))
	_check(pl._idle_reported, "マウスの小さな揺れ（1px）では、放置は解除されない")

	pl = _new_log()
	await _advance(pl, 30.0, func(i): if i % 8 == 0: _mouse(Vector2(3.0, 0.0)))
	_check(pl._idle_reported, "ときどき数 px 動くだけ（触れただけ）では、放置は解除されない")

	pl = _new_log()
	var stick := await _advance(pl, 40.0, func(i): _stick(JOY_AXIS_RIGHT_X, 0.7 if i % 2 == 0 else 0.65))
	_check(not stick, "右スティックで見回している間は、放置にならない")

	pl = _new_log()
	await _advance(pl, 30.0, func(i): _stick(JOY_AXIS_LEFT_X, 0.12 if i % 2 == 0 else 0.08))
	_check(pl._idle_reported, "スティックの遊び（0.1 前後）では、放置は解除されない")

	pl = _new_log()
	_key(KEY_W, true)
	await process_frame
	var walking := await _advance(pl, 40.0, func(_i): pass)
	_check(not walking, "W を押しっぱなしで歩いている間（新しい入力がなくても）は、放置にならない")
	_key(KEY_W, false)
	await process_frame
	await _advance(pl, 30.0, func(_i): pass)
	_check(pl._idle_reported, "離して何もしなければ、放置になる")
	_discard(pl)

	print("PLAYTEST IDLE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


## ログを作り直す（時間はこのテストが進める）。書いたファイルは、終わったら消す。
func _new_log():
	var old := _main.get_node_or_null("IdleLog")
	if old:
		_discard(old)
	var pl = LogScript.new()
	pl.name = "IdleLog"
	_main.add_child(pl)
	pl.set_process(false)
	return pl


func _discard(pl) -> void:
	if pl._file:
		var path: String = pl._file.get_path_absolute()
		pl._file.close()
		pl._file = null
		DirAccess.remove_absolute(path)
	pl.free()


## seconds 秒ぶん、STEP ごとに feed(i) で入力を送ってから時間を進める。途中で一度でも放置になったら true。
func _advance(pl, seconds: float, feed: Callable) -> bool:
	var went_idle := false
	var n := int(seconds / STEP)
	for i in n:
		feed.call(i)
		await process_frame
		pl._process(STEP)
		went_idle = went_idle or pl._idle_reported
	return went_idle


func _mouse(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.screen_relative = rel
	Input.parse_input_event(ev)


func _stick(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _key(key: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.keycode = key
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
