extends SceneTree
## 段階 5-1 の検証：射的の星のフィギュア → コイン／つかみ取りの景品 8 つ（固定順・コイン 1 枚で 1 つ）→ 家の鍵で玄関ドア／耳栓・懐中電灯・磁石の効果。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage5a_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m := current_scene
	m.credits_enabled = false
	return m


func _run() -> void:
	var main = await _fresh()
	var room = main.room
	var apt = room.apartment
	var player = main.player
	# ---------------------------------------------------------------- 射的：星の印 → コイン 1
	var star: Node3D = apt.figures[apt.STAR_FIGURE].node
	_check(star.has_node("StarMark") and apt.figures[apt.STAR_FIGURE].get("star", false), "棚の 8 番目のフィギュアに、黄色い星の印がある")
	var plain_idx := 2
	_check(not (apt.figures[plain_idx].node as Node3D).has_node("StarMark"), "ほかのフィギュアには印がない")
	apt.knock_figure(apt.figures[plain_idx].node)
	await create_timer(1.0).timeout
	_check(main.shot_coin_node == null and main.coin_count == 0, "ほかを倒しても、何も出ない（倒れるだけ）")
	apt.knock_figure(star)
	await create_timer(1.2).timeout
	_check(main.shot_coin_node != null and main.hud._message_label.text == main.STAGE5["star_hit"], "星の印を倒すと、コインが落ちる")
	main._on_interact_requested(main.shot_coin_node.get_node("ShotCoinArea"))
	_check(main.coin_count == 1 and main.shot_coin_taken and main.shot_coin_node == null, "コインを拾う（コイン 1 枚目）")

	# ---------------------------------------------------------------- つかみ取り：固定順の景品 8 つ
	var ufo = apt.ufo_catcher
	main.add_coin(7)   # 1（射的）+ 7
	var got := []
	for k in 8:
		if k > 0:
			main.coin_count = maxi(main.coin_count, 1)
		var r: String = ufo.interact("ufo_catcher")
		await create_timer(8.6).timeout
		got.append(r)
	_check(got == ["ufo_win", "ufo_win", "ufo_win", "ufo_win", "ufo_win", "ufo_win", "ufo_win", "ufo_win"], "コイン 1 枚で、必ず景品が出る（8 回）")
	await create_timer(1.2).timeout
	var expect := ["flashlight", "magnifier", "magnet_hook", "earplugs", "rice_pack", "home_key", "blowgun_part", "mahjong_tiles"]
	var all_have := true
	for id in expect:
		all_have = all_have and main.inventory.has(id)
	_check(all_have, "景品は、固定順に、持ち物へ入る（%s）" % str(main.inventory))
	_check(ufo.taken == 8 and ufo.interact("ufo_catcher") == "ufo_empty", "8 つ出ると、景品はなくなる")

	# ---------------------------------------------------------------- 家の鍵：玄関ドア
	var door = room.front_door
	_check(door.locked and door.interact("front_door") == "front_door_locked" and not door.is_open, "玄関ドアは、はじめ鍵がかかっている")
	player.global_position = Vector3(-0.3, 0.0, 1.85)
	var dd := Vector3(-0.95, 1.0, 1.85)   # 扉の中央
	var d: Vector3 = dd - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	player.camera.rotation.x = player._pitch
	await physics_frame
	await physics_frame
	main.select_item(main.inventory.find("home_key"))
	main.use_selected()
	_check(not door.locked and main.hud._message_label.text == main.STAGE5["front_door_unlock"], "家の鍵を玄関ドアに使うと、鍵が開く")
	_check(door.interact("front_door") == "", "開けられる")

	# ---------------------------------------------------------------- 景品の効果
	main.select_item(main.inventory.find("flashlight"))
	await process_frame
	_check(main._flash_light != null and main._flash_light.visible and main._has_light(), "懐中電灯を持つと、前へ細く明るい（スポット）")
	main.select_item(main.inventory.find("earplugs"))
	var AudioSettings := preload("res://scripts/audio_settings.gd")
	var amb0: float = AudioSettings.ambient
	main.use_selected()
	_check(main.earplugs_on and AudioSettings.earplugs, "耳栓をつけると、音が小さくなる")
	main.use_selected()
	_check(not main.earplugs_on and not AudioSettings.earplugs and absf(AudioSettings.ambient - amb0) < 0.001, "もう一度で外れる（設定の音量は変わらない）")
	_check(main.fishing.magnet, "磁石付きの釣り針を持つと、釣りで金属の物が出やすい")

	# ---------------------------------------------------------------- 保存して、復元
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	var st: Dictionary = snap.get("stage4", {})
	_check(int(st.get("ufo_taken", 0)) == 8 and bool(st.get("front_unlocked")) and bool(st.get("shot_coin_taken")), "保存に、景品の数・玄関の鍵・射的のコインが入る")
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.room.apartment.ufo_catcher.taken == 8 and not main.room.front_door.locked and main.shot_coin_taken and main.fishing.magnet, "復元しても、同じ")
	print("STAGE5A TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
