extends SceneTree
## TASK-13 と追加物の確認画像（画角 80°）。実行: SHOT_DIR=保存先 Godot --path . --script res://tests/capture_task13.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main := current_scene
	main.hud._message_panel.visible = false
	main.set_physics_process(false)
	var p = main.player
	p.set_physics_process(false)
	var room = main.room
	var cab = room.mirror_cabinet
	var lock_pt: Vector3 = cab.door_pivot.get_node("Lock").global_position
	# 留め具の近景（施錠中）：ドライバーを持って狙ったときの案内も写す
	main._item_models["driver"] = room.driver_node.get_node("Visual").duplicate()
	room.remove_driver()
	main.has_driver = true
	main.add_item("driver")
	await _shot(main, p, "t13_lock_closeup", Vector3(0.5, 0, 0.45), 1.5, lock_pt, true)
	cab.unlock()
	await create_timer(0.5).timeout
	await _shot(main, p, "t13_lock_unlocked", Vector3(0.5, 0, 0.45), 1.5, lock_pt, false)
	cab.toggle()
	await create_timer(0.7).timeout
	await _shot(main, p, "t13_mirror_cabinet_open", Vector3(0.2, 0, 0.3), 1.5, Vector3(0.92, 1.5, 0.1), false)
	await _shot(main, p, "t13_razor_shelf", Vector3(0.45, 0, 0.35), 1.5, Vector3(0.85, 1.08, 0.2), false)
	room.bathtub.level = 0.4
	room.bathtub.advance(0.0)
	room.bathtub.shower.set_on(true)
	await create_timer(0.3).timeout
	await _shot(main, p, "t13_shower_and_bottles", Vector3(0.1, 0, -0.1), 1.5, Vector3(0.5, 1.0, -1.0), false)
	await _shot(main, p, "t13_hall_movie_posters", Vector3(0.0, 0, 1.4), 1.5, Vector3(0.0, 1.3, 2.4), false)
	quit()


func _shot(main: Node, p, name: String, pos: Vector3, eye: float, look: Vector3, with_prompt: bool) -> void:
	p.global_position = pos
	p.camera.position.y = eye
	var d: Vector3 = look - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p.camera.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85.0), deg_to_rad(85.0))
	for i in 4:
		await physics_frame
	main._process(0.0)
	if not with_prompt:
		main.hud.set_prompt("")
	main.hud._message_panel.visible = false
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))
