extends SceneTree
## 段階 6 の仕上げ：虫眼鏡の使い道／松明の材料の救済（釣り）／段階 5〜6 のヒント。
## 実行: Godot --headless --path . --script res://tests/stage6c_test.gd

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
	# 虫眼鏡
	main.add_item("magnifier")
	main.select_item(main.inventory.find("magnifier"))
	for k in ["magnifier_feed", "magnifier_safe", "magnifier_dot", "magnifier_use"]:
		_check(main.STAGE5.has(k), "虫眼鏡の文章：%s" % k)
	# 救済：松明を捨てたあと、材料が戻る
	room.exterior.ladder_down = true
	main.items_found["match_stick"] = true
	main.items_found["room_key"] = true
	_check(main._story_catch_next() == "", "ふだんは、救済の釣りは出ない")
	main.thrown_torch = Node3D.new()
	_check(main._story_catch_next() == "match_stick", "松明を捨てて、マッチ棒がないときだけ、また釣れる")
	main.add_item("match_stick")
	_check(main._story_catch_next() == "wood_stick", "つぎは木の棒")
	main.add_item("wood_stick")
	_check(main._story_catch_next() == "", "そろえば、もう釣れない")
	main._on_story_caught("wood_stick")
	_check(main.inventory.count("wood_stick") >= 1, "釣れた木の棒を持てる")
	# ヒント
	var ids := []
	for h in main.progress._hints():
		ids.append(h.id)
	var want := ["s6_medal", "s6_dart", "s6_blowgun", "s6_mj", "s6_scope", "s5_feed", "s5_phone", "s5_safe", "s5_cards", "s5_book2", "s5_book", "s5_door", "s5_prize", "s5_star"]
	var all := true
	for w in want:
		all = all and ids.has(w)
	_check(all, "段階 5〜6 のヒントが用意されている")
	print("STAGE6C TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
