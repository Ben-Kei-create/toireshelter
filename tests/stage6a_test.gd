extends SceneTree
## 段階 6-1 の検証：芯 2 つ（小皿の芯／使い切った芯）→ 望遠鏡 → 天井の点 → 詰め麻雀（九蓮宝燈）→ メダル → つかみ取りで百円玉。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage6a_test.gd

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
	var sup = room.supplies
	# ---- 芯：予備ロールを付けると小皿に芯が出る
	main.add_item("spare_roll")
	sup.toggle_cover()
	await create_timer(0.5).timeout
	sup.install_roll()
	await create_timer(0.9).timeout
	_check(sup.has_paper and sup._dish_core.visible, "ロールを付けると、小皿に芯が出る")
	main._on_interact_requested(sup.get_node("CoreDish/DishCoreArea"))
	_check(main.inventory.has("tp_core") and sup.dish_core_taken, "小皿の芯を取れる")
	# ---- 紙を引いて、使い切る
	var holder: Area3D = sup.get_node("PaperHolder/HolderArea")
	for i in 5:
		main._on_interact_requested(holder)
	_check(sup.used_up and not sup.has_paper, "紙を何度も引くと、使い切って、芯だけが残る")
	main._on_interact_requested(holder)
	_check(main.inventory.has("tp_core2") and sup.core2_taken, "使い切った芯を取れる")
	# ---- 望遠鏡
	main.add_item("crystal")
	main.select_item(main.inventory.find("crystal"))
	main.use_selected()
	_check(main.inventory.has("telescope") and not main.inventory.has("crystal") and not main.inventory.has("tp_core"), "結晶＋芯で、望遠鏡ができる")
	var dot: Area3D = room.apartment.get_node("CeilingDot/CeilingDotArea")
	main._on_interact_requested(dot)
	_check(main.hud._message_label.text == main.STAGE5["ceiling_dot"], "天井の点は、肉眼では見えない")
	# ---- 詰め麻雀
	main.add_item("mahjong_tiles")
	var mj = load("res://scripts/mahjong_game.gd").new()
	mj.puzzle = true
	mj.start()
	_check(mj.state == "playing" and mj.drawn == 4, "詰め麻雀：配牌が決まっていて、最初に五萬を引く")
	mj.discard(_idx(mj, 27))
	_check(mj.state == "playing" and mj.drawn == 8, "東を捨てると、九萬を引く")
	mj.discard(_idx(mj, 33))
	_check(mj.state == "won" and mj.yaku.has("九蓮宝燈"), "中を捨てると、二萬で九蓮宝燈")
	# ---- メダル（main の流れで）
	main.mahjong = mj
	main._check_chuuren()
	_check(main.inventory.has("medal") and main.medal_given and room.cellar_broken, "九蓮宝燈でメダルが出る（セラーも割れる）")
	# ---- つかみ取りで百円玉
	main.select_item(main.inventory.find("medal"))
	main.use_selected()
	_check(main.inventory.has("medal"), "狙いなしでは、メダルは使えない")
	room.power_on = false
	main._use_medal("ufo_catcher")
	_check(main.inventory.has("medal"), "停電中は、メダルを入れられない")
	room.power_on = true
	main._use_medal("ufo_catcher")
	await create_timer(0.5).timeout
	_check(main.inventory.has("yen100") and not main.inventory.has("medal"), "電気がついていれば、メダルが百円玉に変わる")
	main.add_item("medal")
	# 保存と復元
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	var s2 = main.room.supplies
	_check(main.medal_given and main.inventory.has("medal") and s2.used_up and s2.core2_taken and s2.dish_core_taken, "復元しても、メダル・芯の状態は同じ")
	print("STAGE6A TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _idx(mj, tile: int) -> int:
	var all: Array = mj.hand + [mj.drawn]
	return all.find(tile)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
