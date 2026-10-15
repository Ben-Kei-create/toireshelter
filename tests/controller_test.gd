extends SceneTree
## コントローラ（スティック・ボタン）と、操作の案内（覚えた操作だけが説明に出る）。
## 実行: Godot --headless --path . --script res://tests/controller_test.gd

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


func _btn(b: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e


func _run() -> void:
	var main = await _fresh()
	var need := {"interact": JOY_BUTTON_A, "use_item": JOY_BUTTON_X, "action": JOY_BUTTON_Y, "crouch": JOY_BUTTON_B, "item_prev": JOY_BUTTON_LEFT_SHOULDER, "item_next": JOY_BUTTON_RIGHT_SHOULDER, "inspect_item": JOY_BUTTON_DPAD_UP, "drop_item": JOY_BUTTON_DPAD_DOWN, "message_log": JOY_BUTTON_DPAD_LEFT, "notebook": JOY_BUTTON_BACK, "pause": JOY_BUTTON_START}
	var all := true
	for a in need:
		var ev := _btn(need[a])
		all = all and InputMap.event_is_action(ev, a)
	_check(all, "コントローラのボタンが、操作に割り当てられている")
	var axes_ok := true
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0], ["look_up", JOY_AXIS_RIGHT_Y, -1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		axes_ok = axes_ok and InputMap.event_is_action(m, pair[0])
	_check(axes_ok, "左スティックで歩き、右スティックで見回す")
	# LB / RB で持ち物を変える
	for id in ["magnifier", "earplugs", "home_key"]:
		main.add_item(id)
	main.select_item(0)
	main._unhandled_input(_btn(JOY_BUTTON_RIGHT_SHOULDER))
	_check(main.selected == 1, "RB で次の持ち物")
	main._unhandled_input(_btn(JOY_BUTTON_RIGHT_SHOULDER))
	main._unhandled_input(_btn(JOY_BUTTON_RIGHT_SHOULDER))
	_check(main.selected == 0, "RB で最後の次は最初へ")
	main._unhandled_input(_btn(JOY_BUTTON_LEFT_SHOULDER))
	_check(main.selected == 2, "LB で前の持ち物（最初の前は最後）")
	# 操作の案内
	var g = main.guide
	g.learned.clear()
	g.tip_shown.clear()
	_check(g.help_text().contains("???? × 13"), "はじめは、操作説明は「???? × 13」だけ")
	main._input(_btn(JOY_BUTTON_Y))
	_check(g.learned.has("action") and g.using_pad, "Y を押すと「座る・入る・立つ」を覚え、コントローラ使用になる")
	_check(g.help_text().contains("座る・入る・立つ：E") and g.help_text().contains("Yボタン"), "覚えた操作の説明が出る（キーボードとコントローラの両方）")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_C
	k.pressed = true
	main._input(k)
	_check(g.learned.has("crouch") and not g.using_pad, "C を押すと「しゃがむ」を覚える")
	_check(g.should_tip("move") and not g.should_tip("crouch"), "覚えた操作の案内は、もう出ない")
	main.hud.show_tip(g.tip_text("move"), 1.0)
	_check(main.hud._intro.visible and not g.should_tip("move"), "案内を出すと、一度だけにする")
	# コードの入力（コントローラ）
	main._open_code("テスト", "番号", 4, true, func(t: String) -> void: main.set_meta("code_result", t))
	main.guide.using_pad = true
	for i in 7:
		main._unhandled_input(_btn(JOY_BUTTON_DPAD_UP))
	main._unhandled_input(_btn(JOY_BUTTON_A))
	main._unhandled_input(_btn(JOY_BUTTON_DPAD_DOWN))
	main._unhandled_input(_btn(JOY_BUTTON_A))
	_check(main._code_buf == "76", "コントローラで、十字キーで選んで A で入れる（%s）" % main._code_buf)
	main._unhandled_input(_btn(JOY_BUTTON_B))
	_check(main._code_buf == "7", "B で 1 文字消える")
	main._unhandled_input(_btn(JOY_BUTTON_START))
	_check(not main.coding and String(main.get_meta("code_result", "")) == "7", "START で決める")
	print("CONTROLLER TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
