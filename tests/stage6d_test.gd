extends SceneTree
## ヘッドホン（こたつの中・話し声のあと BGM・外すと止まる）と、持ち物を置く（G）／拾う、保存と復元。
## 実行: Godot --headless --path . --script res://tests/stage6d_test.gd

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
	var hp_area: Area3D = apt.kotatsu.get_node("Headphones/HeadphonesArea")
	main._on_interact_requested(hp_area)
	_check(main.inventory.has("headphones") and not apt.kotatsu.headphones_node.visible, "こたつの中のヘッドホンを拾える")
	main._hp_audio.build_now()
	var st: AudioStreamWAV = main._hp_audio.stream
	var secs := float(st.data.size()) / 2.0 / st.mix_rate
	_check(st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD and absf(secs - 41.0) < 0.2 and st.loop_begin > 200000, "音は、話し声（13 秒）のあと BGM（28 秒）がくり返す（%.1f 秒）" % secs)
	main.select_item(main.inventory.find("headphones"))
	await process_frame
	_check(main._hp_on and main._hp_player != null and main._hp_player.playing, "手に持つと、音が流れる")
	_check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambient")) < -10.0, "部屋の環境音は、遠くなる")
	main.select_item(-1)
	_check(not main._hp_on and not main._hp_player.playing, "持ち物の選択から外すと、聞こえなくなる")
	_check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambient")) > -6.0, "環境音は、もとに戻る")
	# ---- 置く
	main.player.global_position = Vector3(3.0, 0.0, -0.3)
	main.player.rotation.y = 0.0
	main.player.camera.rotation.x = deg_to_rad(-60.0)
	await physics_frame
	await physics_frame
	main.select_item(-1)
	main._drop_selected()
	_check(main.hud._message_label.text == main.STAGE5["drop_none"], "何も持っていないと、置けない")
	main.add_item("magnifier")
	main.select_item(main.inventory.find("magnifier"))
	var n_inv: int = main.inventory.size()
	main._drop_selected()
	_check(main.placed_items.size() == 1 and not main.inventory.has("magnifier") and main.inventory.size() == n_inv - 1, "狙った先に置くと、持ち物から減る")
	var node: Node3D = main.placed_items[0].node
	_check(node.global_position.y > -0.01 and node.global_position.y < 1.5, "床か机の上に置かれる（y=%.2f）" % node.global_position.y)
	main.add_coin(1)
	main.select_item(main.inventory.find("ufo_coin"))
	main._drop_selected()
	_check(main.placed_items.size() == 1 and main.hud._message_label.text == main.STAGE5["drop_no"], "UFOコインは置けない")
	# 保存と復元
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	var pos := node.global_position
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.placed_items.size() == 1 and main.placed_items[0].node.global_position.distance_to(pos) < 0.01 and main.room.apartment.kotatsu.get_node("Headphones").visible == false, "復元しても、置いた物は同じ場所にある")
	# 拾う
	main._on_interact_requested(main.placed_items[0].node.get_node("PlacedArea"))
	_check(main.inventory.has("magnifier") and main.placed_items.is_empty(), "拾うと持ち物にもどる")
	print("STAGE6D TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
