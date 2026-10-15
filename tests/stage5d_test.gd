extends SceneTree
## 段階 5-4 の検証：黒電話に、カーテンの数字（7305）を入力 → 返却口からコイン。入力画面の操作。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage5d_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m := current_scene
	m.credits_enabled = false
	m.ride_speed = 20.0
	return m


func _key(main: Node, code: int, uni := 0) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	e.unicode = uni
	main._unhandled_input(e)


func _run() -> void:
	var main = await _fresh()
	main._phone_dial()
	await process_frame
	await process_frame
	_check(main.coding and main.hud.is_reader_open(), "入力画面が開く")
	_key(main, KEY_7, 55)
	_key(main, KEY_3, 51)
	_key(main, KEY_X, 120)    # 数字以外は入らない
	_check(main._code_buf == "73", "数字だけ入る（%s）" % main._code_buf)
	_key(main, KEY_BACKSPACE)
	_check(main._code_buf == "7", "Backspace で 1 字消える")
	_key(main, KEY_3, 51)
	_key(main, KEY_0, 48)
	_key(main, KEY_5, 53)
	_key(main, KEY_ENTER)
	_check(not main.coding and not main.reading and not main.hud.is_reader_open(), "Enter で決定して、画面が閉じる")
	await create_timer(0.5).timeout
	_check(main.phone_coin_taken and main.coin_count == 1, "7305 で、返却口からコインが出る（6 枚目）")
	main._phone_number("7305")
	await create_timer(0.3).timeout
	_check(main.coin_count == 1 and main.hud._message_label.text == main.STAGE5["phone_empty"], "2 回目は、空っぽ")
	main._phone_dial()
	await process_frame
	await process_frame
	_key(main, KEY_ESCAPE)
	_check(not main.coding and main.player.controls_enabled, "Esc でやめられる")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.phone_coin_taken, "復元しても、コインは取りずみ")
	print("STAGE5D TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
