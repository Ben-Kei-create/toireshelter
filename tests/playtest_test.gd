extends SceneTree
## 試遊版・行動ログ・植木鉢（釣りをしなくても、コイン・マッチ棒・窓の鍵が手に入る）。
## 実行: Godot --headless --path . --script res://tests/playtest_test.gd

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
	# 植木鉢
	main._search_pot()
	_check(main.pot_searches == 0 and main.coin_count == 0, "浴室が上がる前は、ただの植木鉢")
	main.room.risen = true
	main._search_pot()
	_check(main.coin_count == 1 and main.pot_searches == 1, "1 回目：コイン")
	main._search_pot()
	_check(main.inventory.has("match_stick"), "2 回目：マッチ棒")
	main._search_pot()
	_check(main.inventory.has("room_key"), "3 回目：窓の鍵")
	main._search_pot()
	_check(main.hud._message_label.text == main.STAGE5["pot_empty"], "そのあとは、空っぽ")
	# 行動ログ
	var pl = preload("res://scripts/playtest_log.gd").new()
	main.add_child(pl)
	main.playtest = pl
	main.progress.discover("tub_note")
	main._on_interact_requested(main.room.get_node("HeightGauge/GaugeArea"))
	pl.log_event("probe")
	_check(pl.enabled and pl._file != null, "行動ログが開く")
	# 試遊版
	main.slice_mode = true
	main.region = "balcony"
	main._check_slice_end()
	await create_timer(3.4).timeout
	_check(main.cleared and main.clear_route == "slice", "試遊版は、ベランダに出たら、ここまで")
	print("PLAYTEST TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
