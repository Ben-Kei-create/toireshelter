extends SceneTree
## Codex 指摘のうち、小さな磨き：最初のヒント／窓の鍵の名前／カードの点の記録／ねずみ穴（しゃがんでも）／お隣の窓の予告／松明の合わせ方の案内／独り言は読んでいる文をさえぎらない。
## 実行: Godot --headless --path . --script res://tests/polish_test.gd

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
	main.region = "bath"
	var ids := []
	for h in main.progress._hints():
		if h.ok:
			ids.append(h.id)
	_check(not ids.has("floor"), "最初の浴室では、自室の床のヒントは出ない")
	main.region = "room"
	var ids2 := []
	for h in main.progress._hints():
		if h.ok:
			ids2.append(h.id)
	_check(ids2.has("floor"), "自室に出れば、床のヒントが出る")
	_check(main.ITEMS["room_key"]["name"] == "窓の鍵", "部屋の鍵は、「窓の鍵」の名前")
	main.add_item("blank_card_1")
	_check(main.item_name("blank_card_1") == "白紙のトランプ", "点を見るまでは、ただの白紙のトランプ")
	main.cards_seen["blank_card_1"] = true
	_check(main.item_name("blank_card_1") == "白紙のトランプ（点 4）", "青い光で見たあとは、点の数が名前に付く")
	main.player.set_eye_height(1.6)
	main.player.pose = main.PlayerScript.Pose.CROUCH
	await process_frame
	await process_frame
	_check(main.room.washitsu.get_node("MouseHole").visible, "しゃがむと、目の高さの設定が高くても、ねずみ穴が見える")
	main.add_item("wood_stick")
	main.add_item("match_stick")
	_check(main.hud._message_label.text == main.STAGE5["torch_combine"], "棒とマッチ棒がそろうと、合わせ方の案内が出る")
	main.hud.show_message("大事な文章です", 4.0)
	var n0: int = main._mutter_idle_i
	main._mutter("（独り言）")
	_check(main.hud._message_label.text == "大事な文章です", "独り言は、読んでいる最中の文章をさえぎらない")
	main.room.exterior.break_partition("w", true)
	main.player.global_position = Vector3(-1.0, 0.0, -1.7)
	main._check_neighbor_escape()
	_check(main.hud._message_label.text == main.STAGE5["neighbor_window"] and not main.cleared, "お隣の窓の手前で、予告が出る（まだ終わらない）")
	# 演出を飛ばす（クリック・E・A）
	var m2 := InputEventAction.new()
	m2.action = "interact"
	m2.pressed = true
	main.ride_speed = 1.0
	main._ride_base = 1.0
	main.riding = true
	main._unhandled_input(m2)
	_check(main.ride_speed >= 10.0, "エレベーター・購入の演出は、クリックで飛ばせる（速く進む）")
	main.riding = false
	main.ride_speed = 1.0
	# 拡大した物を、手で回す
	main.hud._zoom.visible = true
	main.hud._zoom_manual = false
	main.hud._zoom_pivot.rotation.y = 0.0
	Input.action_press("move_right")
	main.hud._process(0.1)
	Input.action_release("move_right")
	var r1: float = main.hud._zoom_pivot.rotation.y
	main.hud._process(0.5)
	_check(main.hud._zoom_manual and r1 < 0.0 and is_equal_approx(main.hud._zoom_pivot.rotation.y, r1), "拡大した物は、A／D で手で回せて、回したあとは自動では回らない")
	# クレーンは 2 回目から速い
	var ufo = main.room.apartment.ufo_catcher
	main.coin_count = 3
	main.add_item("ufo_coin")
	ufo.interact("ufo_catcher")
	var t1 := 0.0
	while ufo.busy and t1 < 20.0:
		await physics_frame
		t1 += 1.0 / 60.0
	ufo.interact("ufo_catcher")
	var t2 := 0.0
	while ufo.busy and t2 < 20.0:
		await physics_frame
		t2 += 1.0 / 60.0
	_check(t2 < t1 * 0.7, "クレーンは、2 回目から速い（%.1f 秒 → %.1f 秒）" % [t1, t2])
	# 身長計のシール／玄関の予告／カーテンの一拍
	var gauge: Node = main.room.get_node("HeightGauge/GaugeArea")
	main._on_interact_requested(gauge)
	_check(main.hud._message_label.text == main.STAGE5["height_gauge"], "ドア枠の身長計を調べると、目の高さを変えられると教える")
	var fd = main.room.front_door
	fd.locked = false
	fd.warn_enabled = true
	_check(fd.interact("front_door") == "front_door_warn" and not fd.is_open, "玄関をはじめて押すと、予告だけが出て、開かない")
	_check(fd.interact("front_door") == "" and fd.busy, "もう一度押すと、開く")
	print("POLISH TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
