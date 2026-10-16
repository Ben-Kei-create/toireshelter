extends SceneTree
## 段階 5-3 の検証：白紙のトランプ 4 枚（青い光の下で点が見える）→ 押入れの金庫（点の多い順）→ 景品一覧表。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage5c_test.gd

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
	var closet = apt.closet
	var areas := [closet.get_node("Card0/CardArea"), closet.get_node("Card1/CardArea"), closet.get_node("Card2/CardArea"), apt.get_node("ChairCard/CardArea")]
	for k in 4:
		main._on_interact_requested(areas[k])
	var all := true
	for k in 4:
		all = all and main.inventory.has("blank_card_%d" % k)
	_check(all and main.cards_taken.size() == 4, "白紙のトランプを 4 枚、拾える")
	var safe_area: Area3D = closet.get_node("Safe/SafeArea")
	main._on_interact_requested(safe_area)
	_check(main.hud._message_label.text == main.STAGE5["safe_look"], "金庫を調べると、くぼみが 4 つ")
	# 間違った順：2 の点のカードを先に
	main.select_item(main.inventory.find("blank_card_0"))
	main._place_card("blank_card_0", "closet_safe")
	_check(closet.safe_slots.is_empty() and main.inventory.has("blank_card_0"), "順番が違うと、はね返る")
	# 正しい順：8 → 6 → 4 → 2
	for k in [3, 2, 1]:
		main._place_card("blank_card_%d" % k, "closet_safe")
	_check(closet.safe_slots.size() == 3 and not closet.safe_open, "3 枚置いた時点では、まだ開かない")
	# 途中で間違えると、置いた分も戻る
	var snap_mid: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main._place_card("blank_card_0", "closet_safe")
	_check(closet.safe_open, "点の多い順に 4 枚置くと、金庫が開く")
	await create_timer(0.8).timeout
	_check(main.inventory.has("prize_list") and main.safe_list_taken, "中から、景品一覧表が出る")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.room.apartment.closet.safe_open and main.inventory.has("prize_list") and main.cards_taken.size() == 4, "復元しても、金庫は開いたまま")
	main = await _fresh()
	main.progress.apply(snap_mid)
	await process_frame
	_check(main.room.apartment.closet.safe_slots.size() == 3 and not main.room.apartment.closet.safe_open, "途中の状態も、復元できる")
	# 青い光（停電＋紫の浴室灯）のときだけ、点が見える
	main.room.power_on = false
	main.room.bath_light_on = true
	main.room.bath_purple = true
	main.select_item(main.inventory.find("blank_card_0"))
	main._show_zoom()
	_check(main.hud._zoom_desc.text.contains("点の数"), "青い光の下だと、点の数が分かる")
	print("STAGE5C TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
