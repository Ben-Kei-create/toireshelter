extends SceneTree
## ベランダの隔て板：大きなツルハシ 5 回／小さなツルハシ 100 回（「1994 回」のジョーク）で割れる。釣り竿の側＝おばあちゃんのベランダ（道具箱）、反対側＝お隣（窓から脱出）。
## 実行: Godot --headless --path . --script res://tests/balcony_wall_test.gd

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
	var ext = main.room.exterior
	_check(main.FishingScript.SMALL_PICKAXE[5] == "small_pickaxe", "小さなツルハシは、釣りで手に入る")
	main._on_story_caught("small_pickaxe")
	_check(main.inventory.has("small_pickaxe"), "釣れた小さなツルハシを持てる")
	main.add_item("pickaxe")
	# 大きなツルハシ：東（おばあちゃん）を 62 回
	for i in 4:
		main._hit_partition("pickaxe", "e")
	_check(not ext.part_open["e"] and main.wall_hits["e"] == 4, "4 回では、まだ割れない")
	main._hit_partition("pickaxe", "e")
	_check(ext.part_open["e"] and not ext.part_nodes["e"].visible, "大きなツルハシ 5 回で割れる（おばあちゃんの側）")
	_check(ext.chest_node != null, "おばあちゃんのベランダに、道具箱がある")
	# 小さなツルハシ：西（お隣）は 1994 回
	for i in 99:
		main._hit_partition("small_pickaxe", "w")
	_check(not ext.part_open["w"], "小さなツルハシは、99 回ではまだ")
	main._hit_partition("small_pickaxe", "w")
	_check(ext.part_open["w"], "小さなツルハシは「1994 回」と言いつつ、100 回で割れる（お隣の側）")
	# 道具箱
	main._open_chest()
	_check(main.reading and main.progress.discovered.has("granny_chest"), "道具箱で、釣りの種類の一覧が読める")
	main.inventory.erase("small_pickaxe")
	main.items_found.erase("small_pickaxe")
	main.chest_small_taken = false
	main._close_reader()
	main.hud.hide_reader()
	# 保存と復元
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.room.exterior.part_open["e"] and main.room.exterior.part_open["w"] and main.wall_hits["w"] == 100, "復元しても、壊れたまま")
	# 脱出
	main.player.global_position = Vector3(-2.0, 0.0, -1.7)
	main._check_neighbor_escape()
	_check(main.cleared and main.clear_route == "neighbor", "お隣の窓の側へ行くと、脱出（お隣さんの窓から脱出）")
	print("BALCONY WALL TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
