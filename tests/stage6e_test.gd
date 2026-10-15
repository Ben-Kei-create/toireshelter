extends SceneTree
## ねずみ穴（目の高さ 140cm 以下だけ）／ダクトの音（耳栓）／手かがみの光の筋。
## 実行: Godot --headless --path . --script res://tests/stage6e_test.gd

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
	var w = main.room.washitsu
	main.player.set_eye_height(1.6)
	await process_frame
	await process_frame
	_check(not w.get_node("MouseHole").visible and w.get_node("MouseHole/MouseHoleArea").collision_layer == 0, "目の高さが高いと、ねずみ穴は見えない")
	main.player.set_eye_height(1.3)
	await process_frame
	await process_frame
	_check(w.get_node("MouseHole").visible and w.get_node("MouseHole/MouseHoleArea").collision_layer != 0, "130 cm なら、ねずみ穴が見える")
	main.region = "duct"
	main.earplugs_on = false
	main._update_duct_sound()
	_check(not main._duct_heard, "耳栓なしでは、ダクトの音は聞こえない")
	main.earplugs_on = true
	main._update_duct_sound()
	_check(main._duct_heard and main.progress.has_note("duct_sound"), "耳栓をすると、壁の向こうの音（ノートに残る）")
	var n0 := main.get_child_count()
	main._flash_beam(Vector3(0, 1, 0), Vector3(1, 1, 1))
	_check(main.get_child_count() == n0 + 1, "光の筋ができる")
	await create_timer(1.8).timeout
	_check(main.get_child_count() == n0, "光の筋は、少しして消える")
	print("STAGE6E TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
