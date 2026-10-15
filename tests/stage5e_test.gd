extends SceneTree
## 段階 5-5 の検証：水槽の餌箱（鏡文字の FLUSH）→ コインが水槽の底へ → 拾う（7 枚目）。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage5e_test.gd

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


func _run() -> void:
	var main = await _fresh()
	var aq = main.room.apartment.aquarium
	var area: Area3D = aq.get_node("FeedBox/FeedBoxArea")
	main._on_interact_requested(area)
	await process_frame
	await process_frame
	_check(main.coding and not main._code_digits and main._code_len == 5, "餌箱を調べると、5 文字の入力画面が開く")
	main._code_buf = "FLASH"
	main._close_code(true)
	_check(not aq.feed_unlocked and aq.coin_node == null, "違う言葉では開かない")
	main._try_feed_lock("FLUSH")
	_check(aq.feed_unlocked and aq.coin_node != null, "FLUSH で開き、コインが水槽の底に現れる")
	main._on_interact_requested(aq.coin_node.get_node("TankCoinArea"))
	_check(main.coin_count == 1 and aq.coin_taken and aq.coin_node == null, "コインを拾う（7 枚目）")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	var aq2 = main.room.apartment.aquarium
	_check(aq2.feed_unlocked and aq2.coin_taken and aq2.coin_node == null, "復元しても、開いたまま・コインは取りずみ")
	print("STAGE5E TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
