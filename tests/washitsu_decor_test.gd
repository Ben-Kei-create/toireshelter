extends SceneTree
## 和室：仏壇（暗いときと灯ったとき）と、天井ぎわをまわる提灯（家宝が開くまでは灯らない）。
## 実行: Godot --headless --path . --script res://tests/washitsu_decor_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	main.credits_enabled = false
	var w = main.room.washitsu
	_check(w.get_node_or_null("Butsudan") != null and w.get_node("Butsudan/ButsudanArea") != null, "和室に仏壇がある")
	_check(w._lanterns.size() == w.LANTERN_N and not w.festive, "提灯がぐるりに並ぶ（はじめは灯らない）")
	var p0: Vector3 = w._lanterns[0].node.position
	await create_timer(0.6).timeout
	_check(w._lanterns[0].node.position.distance_to(p0) > 0.001, "提灯はゆっくり回る")
	var inside := true
	for l in w._lanterns:
		var q: Vector3 = l.node.position
		inside = inside and absf(q.x) < w.HX and absf(q.z) < w.HZ and q.y > 1.8 and q.y < w.H
	_check(inside, "提灯は、部屋の中の、天井ぎわにある")
	_check(w.get_node("Attic").get_children().filter(func(c): return str(c.name).begins_with("AtticRoom")).size() == 6 and w._attic_lanterns.size() == 9, "天井のすき間の上に、屋根裏の部屋が横一列に 6 つ、提灯の列がある")
	var ap0: Vector3 = w._attic_lanterns[0].position
	await create_timer(0.6).timeout
	_check(w._attic_lanterns[0].position.distance_to(ap0) > 0.001, "屋根裏の提灯は、ゆっくり回る")
	main._on_interact_requested(w.get_node("Butsudan/ButsudanArea"))
	_check(main.hud._message_label.text == main.STAGE5["butsudan_dark"], "暗いときの仏壇")
	w.open_heirloom(true)
	_check(w.festive and (w._lanterns[0].mat as StandardMaterial3D).emission_energy_multiplier > 1.0 and (w._candle_lights[0] as OmniLight3D).light_energy >= 0.0, "家宝が開くと、提灯とろうそくが灯る")
	main._on_interact_requested(w.get_node("Butsudan/ButsudanArea"))
	_check(main.hud._message_label.text == main.STAGE5["butsudan_lit"], "灯ったあとの仏壇")
	print("WASHITSU DECOR TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
