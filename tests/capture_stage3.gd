extends SceneTree
## 段階 3 の確認画像：ブレーカー（蓋が閉・開・ヒューズ）、ホールのふすま・ドアノブ・小さな扉、暗い部屋と松明。
## 実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_stage3.gd
func _initialize() -> void:
	_run()


func _shot(main: Node, name: String, pos: Vector3, target: Vector3) -> void:
	var p = main.player
	p.global_position = pos
	var d: Vector3 = target - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud._message_panel.visible = false
	main.set_process(false)
	main.player.set_physics_process(false)
	var room = main.room
	room.rise_unit(main.player, true)
	room.exterior.lower_ladder(room.exterior.DUCT_FLOOR + room.rise_offset, true)
	await process_frame
	var br = room.exterior.breaker
	await _shot(main, "s3_breaker_closed", Vector3(1.9, 0.0, -1.75), br.global_position)
	br.restore(true, false)
	await _shot(main, "s3_breaker_open", Vector3(1.9, 0.0, -1.75), br.global_position)
	br.restore(true, true)
	await _shot(main, "s3_breaker_fuse", Vector3(1.9, 0.0, -1.75), br.global_position)
	# ホールのふすま（閉）とドアノブ、小さな扉
	var apt = room.apartment
	await _shot(main, "s3_fusuma", Vector3(0.0, 0.0, 1.6), Vector3(0.95, 1.0, 1.85))
	await _shot(main, "s3_knob", Vector3(0.4, 0.0, 1.5), room.knob_node.global_position)
	main.add_item("torch")
	main._give_stage3_model("torch")
	main.select_item(main.inventory.find("torch"))
	var hatch: Node3D = room.get_node("FuseHatch")
	await _shot(main, "s3_hatch_closed", Vector3(hatch.global_position.x, 0.0, hatch.global_position.z + 0.7), hatch.global_position)
	room.open_hatch(true)
	await _shot(main, "s3_hatch", Vector3(hatch.global_position.x, 0.0, hatch.global_position.z + 0.7), hatch.global_position)
	await _shot(main, "s3_knob_torch", Vector3(0.4, 0.0, 1.5), room.knob_node.global_position)
	# 暗い部屋と松明
	await _shot(main, "s3_torch_room", Vector3(2.5, 0.0, 0.8), Vector3(3.5, 0.9, -0.2))
	# 捨てた松明
	main.restore_thrown_torch()
	await _shot(main, "s3_torch_balcony", Vector3(1.8, 0.0, -1.75), Vector3(2.4, 0.1, -1.75))
	quit()
