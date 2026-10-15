extends SceneTree
## 段階 5-2 の検証：椅子の悪口本 → 便器に流す（蓋が必要）→ 詰まる → 濡れた本とコイン。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage5b_test.gd

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
	var room = main.room
	var apt = room.apartment
	var t = room.toilet
	_check(apt.bad_book_node != null and apt.bad_book_node.visible, "椅子の上に、悪口本がある")
	main._on_interact_requested(apt.bad_book_node.get_node("BadBookArea"))
	_check(main.inventory.has("bad_book") and apt.bad_book_taken and not apt.bad_book_node.visible, "拾うと、持ち物に入る")
	# 蓋が閉じているときは流せない
	t.lid_open = false
	main.select_item(main.inventory.find("bad_book"))
	main._flush_book("toilet")
	_check(main.inventory.has("bad_book") and main.hud._message_label.text == main.STAGE5["flush_need_lid"], "蓋が閉まっていると、流せない")
	main._flush_book("tank_lid")
	_check(main.inventory.has("bad_book"), "便器以外では流せない")
	t.lid_open = true
	var c0: int = main.coin_count
	main._flush_book("toilet")
	_check(not main.inventory.has("bad_book"), "便器に流すと、本が手元から消える")
	await create_timer(0.6).timeout
	_check(t.clogged, "便器が詰まる")
	await create_timer(0.8).timeout
	_check(main.inventory.has("bad_book_wet") and main.coin_count == c0 + 1, "濡れた本が戻り、コインが 1 枚出る")
	t.flushing = false
	_check(t.interact("flush_lever") == "toilet_clogged", "詰まったあとは、レバーを引いても流れない")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.room.toilet.clogged and main.room.apartment.bad_book_taken and main.inventory.has("bad_book_wet"), "復元しても、詰まったまま・本は戻らない")
	print("STAGE5B TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
