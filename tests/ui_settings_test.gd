extends SceneTree
## 文字の大きさ・キーの割り当て・景品の拡大表示。
## 実行: Godot --headless --path . --script res://tests/ui_settings_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	main.credits_enabled = false
	main.ride_speed = 20.0
	var hud = main.hud
	# 文字の大きさ
	var lab: Label = hud._message_label
	var base := lab.get_theme_font_size("font_size")
	hud.set_text_scale(1.5)
	_check(lab.get_theme_font_size("font_size") == int(round(base * 1.5)), "文字の大きさを 150 %% にすると、メッセージも大きくなる（%d → %d）" % [base, lab.get_theme_font_size("font_size")])
	hud.set_text_scale(0.8)
	_check(lab.get_theme_font_size("font_size") == int(round(base * 0.8)), "80 %% では小さくなる（もとの大きさから計算し直す）")
	hud.set_text_scale(1.0)
	_check(lab.get_theme_font_size("font_size") == base, "100 %% でもとにもどる")
	# キーの割り当て
	var before: Array = InputMap.action_get_events("crouch")
	main._on_key_rebound("crouch", KEY_V)
	var has_v := false
	var has_c := false
	for ev in InputMap.action_get_events("crouch"):
		if ev is InputEventKey:
			has_v = has_v or (ev as InputEventKey).physical_keycode == KEY_V
			has_c = has_c or (ev as InputEventKey).physical_keycode == KEY_C
	_check(has_v and not has_c, "しゃがむを V に割り当てると、C は外れる")
	var pad := false
	for ev in InputMap.action_get_events("crouch"):
		pad = pad or ev is InputEventJoypadButton
	_check(pad, "コントローラのボタンは、そのまま残る")
	main._on_key_rebound("action", KEY_V)   # すでに V を持つ「しゃがむ」から、外れる
	var crouch_has_v := false
	for ev in InputMap.action_get_events("crouch"):
		crouch_has_v = crouch_has_v or (ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_V)
	_check(not crouch_has_v, "同じキーを別の動作に割り当てると、前の動作からは外れる（かぶらない）")
	_check(hud._key_buttons["action"].text == "V", "割り当て欄に、いまのキーが出る")
	main.guide.learned["action"] = true
	_check(main.guide.help_text().contains("座る・入る・立つ：V"), "操作の説明も、いまのキーの名前になる")
	main._on_keys_reset()
	var back := false
	for ev in InputMap.action_get_events("crouch"):
		back = back or (ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_C)
	_check(back and hud._key_buttons["crouch"].text == "C", "「もとにもどす」で、初期の割り当てにもどる")
	# 景品の拡大表示
	main.coin_count = 1
	main.add_item("ufo_coin")
	main._on_prize_won(0)
	await create_timer(0.3).timeout
	_check(main.inventory.has("flashlight") and hud.is_zoom_open() and main.selected_item() == "flashlight", "景品が出ると、手に取って、拡大して見せる")
	await create_timer(3.0).timeout
	_check(not hud.is_zoom_open(), "少しすると、拡大は閉じる")
	print("UI SETTINGS TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
