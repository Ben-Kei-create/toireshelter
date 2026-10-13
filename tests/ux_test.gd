extends SceneTree
## 親切なUI・UX（照準の反応・メッセージの履歴・視点の感度・自動一時停止・持ち物の強調）の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/ux_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var hud = main.hud
	var player = main.player
	# --- 照準の反応
	hud.set_aim(true)
	check(hud._dot.color.r > 0.9 and hud._dot.color.b < 0.6 and hud._dot.offset_right > 3.0, "調べられる物を狙うと、照準が大きく温かい色になる")
	hud.set_aim(false)
	check(hud._dot.color.b > 0.9 and hud._dot.offset_right < 2.5, "外すと元に戻る")
	# --- メッセージの履歴
	for i in 35:
		hud.show_message("テスト%d" % i)
	check(hud._messages.size() == 30 and hud._messages[29] == "テスト34", "メッセージは最近の 30 件を覚える")
	hud.show_message("テスト34")
	check(hud._messages.size() == 30, "同じメッセージが続けて出ても、履歴は増えない")
	var ev := InputEventAction.new()
	ev.action = "message_log"
	ev.pressed = true
	main._unhandled_input(ev)
	check(hud.is_log_open() and hud._log_label.text.begins_with("・テスト34"), "H で履歴が開き、新しい順に出る")
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	main._unhandled_input(esc)
	check(not hud.is_log_open() and not main.paused, "Esc は履歴を閉じるだけ（一時停止にならない）")
	main.gaming = true
	main._unhandled_input(ev)
	check(not hud.is_log_open(), "ゲーム・麻雀・のぞき穴の最中には履歴を開かない")
	main.gaming = false
	# --- 視点の感度
	main._on_sensitivity_changed(2.0)
	check(is_equal_approx(player.sensitivity, 2.0), "感度の倍率が反映される（200%）")
	main._on_sensitivity_changed(99.0)
	check(player.sensitivity <= player.SENS_MAX, "感度は上限を超えない")
	main._on_sensitivity_changed(1.0)
	var cfg := ConfigFile.new()
	cfg.load(main.SETTINGS_PATH)
	check(is_equal_approx(float(cfg.get_value("player", "sensitivity", 0.0)), 1.0), "感度は保存される")
	# --- 自動一時停止
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.paused, "ウィンドウから離れると自動で一時停止する")
	main._resume()
	main.gaming = true
	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not main.paused, "ゲーム中（テレビ・のぞき穴・麻雀）は自動で止めない")
	main.gaming = false
	# --- 持ち物の強調（新しく加わった欄がふくらんで戻る）
	main.add_item("driver")
	var slot: Control = hud._slot_panels[0]
	check(slot.scale.x > 1.05, "拾った物の欄が、いったん大きくなって強調される")
	await create_timer(0.7).timeout
	check(absf(slot.scale.x - 1.0) < 0.02, "そのあと元の大きさに戻る")
	# --- 遊んだ記録・終了の確認・はじめてのヒント
	check(main.total_examinable > 100, "調べられる物の数を数えている（%d 個）" % main.total_examinable)
	main.examined.clear()
	var tgt: Node = main.room.apartment.get_node("Calendar/CalendarArea")
	main._on_interact_requested(tgt)
	main._on_interact_requested(tgt)
	check(main.examined.size() == 1, "同じ物を何度調べても 1 と数える")
	check(main._stats_text().contains("調べた物 1 / ") and main._stats_text().contains("プレイ時間"), "設定画面に「プレイ時間」と「調べた物」が出る")
	main._pause()
	check(hud._stats_label.text.contains("調べた物 1"), "一時停止すると記録が更新される")
	main._resume()
	for c in hud.quit_pressed.get_connections():
		hud.quit_pressed.disconnect(c.callable)   # 本物の終了処理は外して、押した回数だけ数える
	var quit_hits := [0]
	hud.quit_pressed.connect(func() -> void: quit_hits[0] += 1)
	hud._on_quit_clicked()
	check(quit_hits[0] == 0 and hud._quit_button.text == "もう一度押すと終了", "「終了」は 1 回目では終わらず、確認の表示に変わる")
	hud._on_quit_clicked()
	check(quit_hits[0] == 1, "2 回目で終了する")
	hud._quit_armed = false
	hud.show_intro("テスト", 0.3)
	check(hud._intro.visible, "はじめてのヒントが出る")
	await create_timer(2.0).timeout
	check(not hud._intro.visible, "数秒で消える")
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
